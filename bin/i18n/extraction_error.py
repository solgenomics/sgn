"""Shared extraction failures without backend/frontend import cycles."""


class ExtractionError(ValueError):
    """Report unsupported or ambiguous source without executing that source."""


def has_literal_message_fields(record):
    """Check the shared context/source prefix of literal-message protocols."""
    return (
        isinstance(record, dict)
        and isinstance(record.get("context"), str)
        and isinstance(record.get("source"), str)
        and bool(record["source"])
    )
