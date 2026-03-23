# core/pipeline.py

from .sql_templates import classify_intent, render_from_intent


class QueryPipeline:
    """
    Simple intent → SQL rendering pipeline.
    Output dict keys (stable for tests / callers):
      input   : original text
      intent  : classified intent (or __UNKNOWN__/__BLOCKED__/__RAW__)
      kwargs  : extracted arguments
      valid   : True if we have executable SQL (or raw safe SQL)
      sql     : SQL text (if valid)
      params  : tuple of parameters (if any)
      message : human-readable status (always present)
    """

    def run(self, text: str):
        intent, kwargs = classify_intent(text)

        out = {
            "input": text,
            "intent": intent,
            "kwargs": kwargs,
            "valid": False,
            "sql": None,
            "params": (),
            "message": None,
        }

        # Blocked (destructive)
        if intent == "__BLOCKED__":
            out["message"] = "Blocked: destructive statement."
            return out

        # Unknown (non-destructive)
        if intent == "__UNKNOWN__":
            out["message"] = "Could not classify intent."
            return out

        # Raw user-provided SELECT / WITH
        if intent == "__RAW__":
            out["valid"] = True
            out["sql"] = text
            out["params"] = ()
            out["message"] = "Raw query accepted."
            return out

        # Template-backed intent
        sql, params = render_from_intent(intent, **kwargs)
        if sql:
            out["valid"] = True
            out["sql"] = sql
            out["params"] = params
            out["message"] = f"Rendered intent '{intent}'."
        else:
            # Fallback safeguard (should rarely happen)
            out["intent"] = "__UNKNOWN__"
            out["message"] = "Could not classify intent."
        return out

