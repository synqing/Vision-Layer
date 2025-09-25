import json
from jsonschema import Draft202012Validator


class Validator:
    def __init__(self, facts_schema: dict, brief_schema: dict):
        self.facts_validator = Draft202012Validator(facts_schema)
        self.brief_validator = Draft202012Validator(brief_schema)

    def validate_facts(self, facts: dict):
        self.facts_validator.validate(facts)

    def validate_brief(self, brief: dict):
        self.brief_validator.validate(brief)

