from pathlib import Path
import shutil
root = Path(__file__).resolve().parents[1]
for source in (root / "web/dist").rglob("*"):
    if source.is_file():
        target = root / "docs" / source.relative_to(root / "web/dist")
        target.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(source, target)
(root / "docs/.nojekyll").touch()
