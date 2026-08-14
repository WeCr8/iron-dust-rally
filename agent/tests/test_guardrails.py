import unittest

from agent.guardrails import ResponseRejected, parse_model_json, validate_files


CONFIG = {"allowed_roots": ["game", "docs"], "denied_paths": ["game/.godot"], "max_patch_lines": 5}


class GuardrailTests(unittest.TestCase):
    def test_parse_contract(self):
        data = parse_model_json('{"summary":"ok","files":[],"tests":[],"task_complete":false,"blocker":"x"}')
        self.assertEqual(data["blocker"], "x")

    def test_extracts_paths(self):
        files = [{"path": "game/a.gd", "content": "b\n"}]
        self.assertEqual(validate_files(files, CONFIG), ["game/a.gd"])

    def test_rejects_escape(self):
        files = [{"path": "../x", "content": "b\n"}]
        with self.assertRaises(ResponseRejected):
            validate_files(files, CONFIG)

    def test_rejects_denied_path(self):
        files = [{"path": "game/.godot/x", "content": "b\n"}]
        with self.assertRaises(ResponseRejected):
            validate_files(files, CONFIG)


if __name__ == "__main__":
    unittest.main()
