"""Unified config file toolkit.

Per-format adapters live in sibling modules and are imported lazily by
``cfg_tool.cli`` so that only the selected format (and its optional
third-party dependency) is loaded for each invocation.
"""
