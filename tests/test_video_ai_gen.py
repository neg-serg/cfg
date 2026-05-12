"""Contract tests for gen-video CLI and video-ai-generate.sh."""

from tests import REPO_ROOT_PATH

SCRIPTS_DIR = REPO_ROOT_PATH / "states" / "scripts"
CONFIGS_DIR = REPO_ROOT_PATH / "states" / "configs" / "video-ai"




def test_gen_video_parses_preset_flag():
    src = (SCRIPTS_DIR / "gen-video").read_text()
    assert "-r|--res" in src or "--res" in src


def test_gen_video_all_flags():
    src = (SCRIPTS_DIR / "gen-video").read_text()
    assert "-m|--model" in src
    assert "-i|--image" in src
    assert "-c|--cfg" in src
    assert "-s|--steps" in src
    assert "-f|--frames" in src
    assert "--lowvram" in src
    assert "--compat" in src
    assert "--list" in src
    assert "--dry-run" in src
    assert "--help" in src



def test_generate_sh_default_steps_is_8():
    src = (SCRIPTS_DIR / "video-ai-generate.sh").read_text()
    assert "STEPS=8" in src



def test_runners_sls_deploys_gen_video():
    src = (REPO_ROOT_PATH / "states" / "video_ai" / "runners.sls").read_text()
    assert "gen-video" in src or "gen_video" in src
    assert "video_ai.runners.gen_video" in src
