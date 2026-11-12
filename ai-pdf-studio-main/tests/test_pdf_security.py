import json
from pathlib import Path

from pypdf import PdfReader, PdfWriter
from pypdf.generic import DecodedStreamObject, DictionaryObject, NameObject

from ai_pdf_studio.pdf import PdfSecurityService


def _document(path: Path) -> None:
    writer = PdfWriter()
    writer.add_blank_page(width=400, height=400)
    writer.add_metadata({"/Title": "Private document", "/Author": "Test"})
    with path.open("wb") as stream:
        writer.write(stream)


def _text_document(path: Path) -> None:
    writer = PdfWriter()
    page = writer.add_blank_page(width=400, height=400)
    font = DictionaryObject({
        NameObject("/Type"): NameObject("/Font"),
        NameObject("/Subtype"): NameObject("/Type1"),
        NameObject("/BaseFont"): NameObject("/Helvetica"),
    })
    page[NameObject("/Resources")] = DictionaryObject({
        NameObject("/Font"): DictionaryObject({NameObject("/F1"): font}),
    })
    stream = DecodedStreamObject()
    stream.set_data(b"BT /F1 20 Tf 40 200 Td (SECRET) Tj ET")
    page[NameObject("/Contents")] = stream
    with path.open("wb") as output:
        writer.write(output)


def test_password_protection_and_removal_preserve_source(tmp_path: Path) -> None:
    source = tmp_path / "source.pdf"
    protected = tmp_path / "protected.pdf"
    unlocked = tmp_path / "unlocked.pdf"
    _document(source)
    service = PdfSecurityService()

    service.protect(source, protected, user_password="secret", permissions=("print",))
    reader = PdfReader(str(protected))
    assert reader.is_encrypted
    assert reader.decrypt("wrong") == 0
    assert int(reader.decrypt("secret")) != 0

    service.remove_password(protected, unlocked, password="secret")
    assert not PdfReader(str(unlocked)).is_encrypted
    assert not PdfReader(str(source)).is_encrypted


def test_metadata_removal_and_detached_signature_validation(tmp_path: Path) -> None:
    source = tmp_path / "source.pdf"
    clean = tmp_path / "clean.pdf"
    signature = tmp_path / "source.sig"
    key_path = tmp_path / "key.pem"
    _document(source)
    service = PdfSecurityService()

    service.remove_metadata(source, clean)
    assert "/Title" not in PdfReader(str(clean)).metadata
    assert "/Author" not in PdfReader(str(clean)).metadata

    from cryptography.hazmat.primitives import serialization
    from cryptography.hazmat.primitives.asymmetric import rsa

    key = rsa.generate_private_key(public_exponent=65537, key_size=2048)
    key_path.write_bytes(
        key.private_bytes(
            serialization.Encoding.PEM,
            serialization.PrivateFormat.PKCS8,
            serialization.NoEncryption(),
        )
    )
    service.sign(source, signature, private_key_pem=key_path.read_bytes())
    assert service.validate_signature(source, signature)
    source.write_bytes(source.read_bytes() + b"tampered")
    assert not service.validate_signature(source, signature)


def test_signature_payload_is_json_and_reports_invalid_signature(tmp_path: Path) -> None:
    source = tmp_path / "source.pdf"
    signature = tmp_path / "source.sig"
    _document(source)
    signature.write_text(json.dumps({"signature": "invalid"}), encoding="utf-8")
    assert not PdfSecurityService().validate_signature(source, signature)


def test_redaction_search_writes_verified_pdf_without_searchable_text(tmp_path: Path) -> None:
    from ai_pdf_studio.redaction import RedactionService

    source = tmp_path / "source.pdf"
    output = tmp_path / "redacted.pdf"
    _text_document(source)

    RedactionService().redact_terms(source, output, ("secret",))

    assert output.is_file()
    assert all(not (page.extract_text() or "").strip() for page in PdfReader(str(output)).pages)
