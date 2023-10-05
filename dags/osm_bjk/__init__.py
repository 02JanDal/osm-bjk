def make_prefix(run_id: str):
    return run_id.replace("-", "").replace(":", "").replace(".", "").replace("+", "").replace("_", "")
