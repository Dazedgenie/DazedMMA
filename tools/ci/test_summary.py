"""Turn GUT's JUnit XML into a plain-language Markdown test report.

Usage: python3 tools/ci/test_summary.py build/test-results.xml >> "$GITHUB_STEP_SUMMARY"
"""
import sys
import xml.etree.ElementTree as ET


def sentence(test_name: str) -> str:
    words = test_name.removeprefix("test_").replace("_", " ")
    return words[:1].upper() + words[1:]


def main(path: str) -> int:
    try:
        root = ET.parse(path).getroot()
    except (OSError, ET.ParseError) as err:
        print(f"## ❌ Tests did not produce a report\n\n`{err}`")
        return 1

    rows, passed, failed = [], 0, 0
    for case in root.iter("testcase"):
        problem = case.find("failure")
        if problem is None:
            problem = case.find("error")
        group = case.get("classname", "").rsplit("/", 1)[-1].removesuffix(".gd").removeprefix("test_")
        if problem is None:
            passed += 1
            rows.append(f"| ✅ | {group} | {sentence(case.get('name', ''))} | |")
        else:
            failed += 1
            detail = " ".join((problem.text or problem.get("message") or "").split()).replace("|", "\\|")
            rows.append(f"| ❌ | {group} | {sentence(case.get('name', ''))} | {detail[:300]} |")

    icon = "✅" if failed == 0 else "❌"
    print(f"## {icon} Tests: {passed} passed, {failed} failed\n")
    print("| | Area | What is checked | Problem |")
    print("|---|---|---|---|")
    print("\n".join(rows))
    return 0 if failed == 0 else 1


if __name__ == "__main__":
    sys.exit(main(sys.argv[1]))
