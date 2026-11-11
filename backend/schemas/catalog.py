from pydantic import BaseModel, Field


class CatalogSettingsUpdate(BaseModel):
    is_public: bool
    selected_product_ids: list[str] = Field(default_factory=list)
    selected_listing_ids: list[str] | None = None
