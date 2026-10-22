# tests/ — automated tests

Unit tests for `sim/` using GUT (`addons/gut`). CI runs them on every PR (`.github/workflows/tests.yml`).
`test_sim_layer_rules.gd` fails the build if anything in `sim/` touches the scene tree, real time, input or unseeded randomness. Test names read as plain sentences,
e.g. `test_takedown_during_body_kick_gets_bonus`.
