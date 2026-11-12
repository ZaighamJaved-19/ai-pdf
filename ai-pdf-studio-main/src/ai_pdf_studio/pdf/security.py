"""Security-sensitive PDF transformations and detached signatures."""

from __future__ import annotations

import base64
import hashlib
import json
import os
import tempfile
from pathlib import Path
from typing import Iterable

from pypdf import PdfReader, PdfWriter
from pypdf.constants import UserAccessPermissions


class PdfSecurityError(ValueError):
    """Raised when a security operation cannot be completed safely."""


_PERMISSIONS = {
    "print": UserAccessPermissions.PRINT,
    "modify": UserAccessPermissions.MODIFY,
    "extract": UserAccessPermissions.EXTRACT,
    "annotate": UserAccessPermissions.ADD_OR_MODIFY,
    "fill_forms": UserAccessPermissions.FILL_FORM_FIELDS,
    "assemble": UserAccessPermissions.ASSEMBLE_DOC,
    "extract_text": UserAccessPermissions.EXTRACT_TEXT_AND_GRAPHICS,
    "high_quality_print": UserAccessPermissions.PRINT_TO_REPRESENTATION,
}


def _check_paths(source: str | Path, output: str | Path) -> tuple[Path, Path]:
    source_path = Path(source).expanduser().resolve()
    output_path = Path(output).expanduser().resolve()
    if source_path == output_path:
        raise PdfSecurityError("The original PDF must be preserved; choose a different output path.")
    if not source_path.is_file():
        raise PdfSecurityError(f"PDF does not exist: {source_path}")
    if source_path.stat().st_size > 512 * 1024 * 1024:
        raise PdfSecurityError("PDF exceeds the safe 512 MB processing limit.")
    output_path.parent.mkdir(parents=True, exist_ok=True)
    return source_path, output_path


def _write_atomically(writer: PdfWriter, output: Path) -> None:
    fd, temporary = tempfile.mkstemp(prefix=".pdf-security-", suffix=".pdf", dir=output.parent)
    os.close(fd)
    temporary_path = Path(temporary)
    try:
        with temporary_path.open("wb") as stream:
            writer.write(stream)
        os.replace(temporary_path, output)
    finally:
        temporary_path.unlink(missing_ok=True)


def _copy_pages(reader: PdfReader, writer: PdfWriter) -> None:
    for page in reader.pages:
        writer.add_page(page)


class PdfSecurityService:
    """Password, metadata, redaction verification, and signature operations."""

    def protect(
        self,
        source: str | Path,
        output: str | Path,
        *,
        user_password: str,
        owner_password: str | None = None,
        permissions: Iterable[str] = (),
        use_128bit: bool = True,
    ) -> Path:
        if not user_password:
            raise PdfSecurityError("A non-empty user password is required.")
        source_path, output_path = _check_paths(source, output)
        reader = PdfReader(str(source_path), strict=False)
        writer = PdfWriter()
        _copy_pages(reader, writer)
        flags = UserAccessPermissions(0)
        for permission in permissions:
            try:
                flags |= _PERMISSIONS[permission]
            except KeyError as exc:
                raise PdfSecurityError(f"Unknown PDF permission: {permission}") from exc
        writer.encrypt(
            user_password,
            owner_password or os.urandom(24).hex(),
            use_128bit=use_128bit,
            permissions_flag=flags,
        )
        _write_atomically(writer, output_path)
        return output_path

    def remove_password(self, source: str | Path, output: str | Path, *, password: str) -> Path:
        if not password:
            raise PdfSecurityError("A password is required to remove PDF encryption.")
        source_path, output_path = _check_paths(source, output)
        reader = PdfReader(str(source_path), strict=False)
        if reader.is_encrypted and int(reader.decrypt(password)) == 0:
            raise PdfSecurityError("The PDF password is invalid.")
        writer = PdfWriter()
        _copy_pages(reader, writer)
        if reader.metadata:
            writer.add_metadata(dict(reader.metadata))
        _write_atomically(writer, output_path)
        return output_path

    def remove_metadata(self, source: str | Path, output: str | Path) -> Path:
        source_path, output_path = _check_paths(source, output)
        reader = PdfReader(str(source_path), strict=False)
        writer = PdfWriter()
        _copy_pages(reader, writer)
        writer.add_metadata({"/Producer": "AI PDF Studio"})
        _write_atomically(writer, output_path)
        return output_path

    def sign(
        self,
        pdf_path: str | Path,
        signature_path: str | Path,
        *,
        private_key_pem: bytes,
        password: bytes | None = None,
    ) -> Path:
        """Create a detached RSA/ECDSA signature without altering the PDF."""
        path = Path(pdf_path).expanduser().resolve()
        if not path.is_file():
            raise PdfSecurityError(f"PDF does not exist: {path}")
        try:
            from cryptography.hazmat.primitives import hashes, serialization
            from cryptography.hazmat.primitives.asymmetric import ec, padding, rsa
        except ImportError as exc:
            raise PdfSecurityError("cryptography is required for signatures.") from exc
        try:
            key = serialization.load_pem_private_key(private_key_pem, password=password)
            digest = hashlib.sha256(path.read_bytes()).digest()
            if isinstance(key, rsa.RSAPrivateKey):
                signature = key.sign(digest, padding.PKCS1v15(), hashes.SHA256())
            elif isinstance(key, ec.EllipticCurvePrivateKey):
                signature = key.sign(digest, ec.ECDSA(hashes.SHA256()))
            else:
                raise PdfSecurityError("Only RSA and ECDSA private keys are supported.")
            public_key = key.public_key()
            public_pem = public_key.public_bytes(
                serialization.Encoding.PEM,
                serialization.PublicFormat.SubjectPublicKeyInfo,
            )
        except PdfSecurityError:
            raise
        except Exception as exc:
            raise PdfSecurityError("The private signing key could not be loaded.") from exc
        target = Path(signature_path).expanduser().resolve()
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_text(
            json.dumps(
                {
                    "algorithm": "RSA-SHA256" if isinstance(key, rsa.RSAPrivateKey) else "ECDSA-SHA256",
                    "sha256": hashlib.sha256(path.read_bytes()).hexdigest(),
                    "signature": base64.b64encode(signature).decode("ascii"),
                    "public_key": public_pem.decode("ascii"),
                },
                indent=2,
            ),
            encoding="utf-8",
        )
        return target

    def validate_signature(self, pdf_path: str | Path, signature_path: str | Path) -> bool:
        path = Path(pdf_path).expanduser().resolve()
        signature_file = Path(signature_path).expanduser().resolve()
        try:
            from cryptography.hazmat.primitives import hashes, serialization
            from cryptography.hazmat.primitives.asymmetric import ec, padding, rsa
            document_hash = hashlib.sha256(path.read_bytes()).hexdigest()
            payload = json.loads(signature_file.read_text(encoding="utf-8"))
            if payload["sha256"] != document_hash:
                return False
            key = serialization.load_pem_public_key(payload["public_key"].encode("ascii"))
            digest = hashlib.sha256(path.read_bytes()).digest()
            signature = base64.b64decode(payload["signature"])
            if isinstance(key, rsa.RSAPublicKey):
                key.verify(signature, digest, padding.PKCS1v15(), hashes.SHA256())
            elif isinstance(key, ec.EllipticCurvePublicKey):
                key.verify(signature, digest, ec.ECDSA(hashes.SHA256()))
            else:
                return False
            return True
        except Exception:
            return False
