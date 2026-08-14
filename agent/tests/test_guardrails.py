import unittest

from agent.guardrails import PatchRejected, changed_paths, parse_model_json, validate_patch


CONFIG = {"allowed_roots": ["game", "docs"], "denied_paths": ["game/.godot"], "max_patch_lines": 5}


class GuardrailTests(unittest.TestCase):
    def test_parse_contract(self):
        data = parse_model_json('{"summary":"ok","patch":"","tests":[],"task_complete":false,"blocker":"x"}')
        self.assertEqual(data["blocker"], "x")

    def test_extracts_paths(self):
        patch = "diff --git a/game/a.gd b/game/a.gd\n--- a/game/a.gd\n+++ b/game/a.gd\n@@ -1 +1 @@\n-a\n+b\n"
        self.assertEqual(changed_paths(patch), ["game/a.gd"])
        self.assertEqual(validate_patch(patch, CONFIG), ["game/a.gd"])

    def test_rejects_escape(self):
        patch = "diff --git a/../x b/../x\n--- a/../x\n+++ b/../x\n@@ -1 +1 @@\n-a\n+b\n"
        with self.assertRaises(PatchRejected):
            validate_patch(patch, CONFIG)

    def test_rejects_denied_path(self):
        patch = "diff --git a/game/.godot/x b/game/.godot/x\n--- a/game/.godot/x\n+++ b/game/.godot/x\n@@ -1 +1 @@\n-a\n+b\n"
        with self.assertRaises(PatchRejected):
            validate_patch(patch, CONFIG)


if __name__ == "__main__":
    unittest.main()
