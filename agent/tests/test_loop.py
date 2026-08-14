import unittest

from agent.run_loop import load_env_file, select_task
from pathlib import Path
import os
import tempfile


class LoopTests(unittest.TestCase):
    def test_selects_priority_ready_task(self):
        tasks = {"tasks": [
            {"id": "A", "priority": 2, "status": "ready", "depends_on": []},
            {"id": "B", "priority": 1, "status": "ready", "depends_on": []},
        ]}
        self.assertEqual(select_task(tasks)["id"], "B")

    def test_dependency_must_be_done(self):
        tasks = {"tasks": [
            {"id": "A", "priority": 1, "status": "ready", "depends_on": ["B"]},
            {"id": "B", "priority": 2, "status": "ready", "depends_on": []},
        ]}
        self.assertEqual(select_task(tasks)["id"], "B")

    def test_done_dependency_unlocks_task(self):
        tasks = {"tasks": [
            {"id": "A", "priority": 1, "status": "ready", "depends_on": ["B"]},
            {"id": "B", "priority": 2, "status": "done", "depends_on": []},
        ]}
        self.assertEqual(select_task(tasks)["id"], "A")

    def test_env_file_does_not_override_process(self):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / ".env"
            path.write_text("LOOP_TEST_KEEP=file\nLOOP_TEST_NEW=value\n")
            os.environ["LOOP_TEST_KEEP"] = "process"
            os.environ.pop("LOOP_TEST_NEW", None)
            load_env_file(path)
            self.assertEqual(os.environ["LOOP_TEST_KEEP"], "process")
            self.assertEqual(os.environ["LOOP_TEST_NEW"], "value")


if __name__ == "__main__":
    unittest.main()
