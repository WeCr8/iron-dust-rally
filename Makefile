.PHONY: doctor preflight validate test verify play web sprint report clean

doctor:
	python3 tools/doctor.py

preflight:
	python3 tools/preflight.py

validate:
	python3 tools/validate_repo.py

test: validate
	python3 -m unittest discover -s agent/tests -v

verify: test
	python3 tools/godot_gate.py

play:
	godot --editor --path game

web:
	python3 tools/export_web.py

sprint:
	python3 tools/sprint.py --hours 6 --max-iterations 60

report:
	python3 tools/report.py

clean:
	python3 tools/clean.py
