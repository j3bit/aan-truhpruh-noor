import io
import unittest
from contextlib import redirect_stdout

from main import main


class MainTest(unittest.TestCase):
    def test_main_runs(self) -> None:
        buffer = io.StringIO()
        with redirect_stdout(buffer):
            main()
        self.assertIn("Hello world!", buffer.getvalue())


if __name__ == "__main__":
    unittest.main()
