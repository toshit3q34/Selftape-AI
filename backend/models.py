# models.py
from sqlalchemy import Column, Integer, String, JSON, UniqueConstraint
from db import Base

class Script(Base):
    __tablename__ = "scripts"

    id = Column(Integer, primary_key=True, index=True)
    user_uid = Column(String, index=True)
    script_hash = Column(String, index=True)
    original_text = Column(String)
    characters = Column(JSON)

    __table_args__ = (
        UniqueConstraint("user_uid", "script_hash", name="_user_script_uc"),
    )
