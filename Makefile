# Helm dev tasks. Run `make bootstrap` first (creates .venv + installs deps).
VENV := .venv
PY := $(VENV)/bin/python

.PHONY: bootstrap test test-backend test-desktop run app clean

bootstrap:
	./scripts/bootstrap.sh

test: test-backend test-desktop

test-backend:
	$(PY) -m pytest -q

test-desktop:
	cd desktop && node --check main.js && node --check backend.js && node --test

run:
	$(PY) -m helm

app:  ## build the .app (needs: pip install -e '.[packaging]')
	./packaging/build-app.sh

clean:
	rm -rf .venv desktop/node_modules dist *.egg-info .pytest_cache
