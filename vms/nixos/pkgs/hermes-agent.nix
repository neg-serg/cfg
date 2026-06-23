{ lib, python3, fetchurl }:

python3.pkgs.buildPythonApplication rec {
  pname = "hermes-agent";
  version = "0.17.0";
  format = "wheel";

  # Skip strict version pin checking — nixpkgs provides compatible versions
  dontCheckRuntimeDeps = true;

  src = fetchurl {
    url = "https://files.pythonhosted.org/packages/e3/e2/d18d5ec6735b412fde47ecac3b6a63874c824c83e9821e1c1f4a07bcff85/hermes_agent-0.17.0-py3-none-any.whl";
    hash = "sha256-8R3MGxaNLbYm74shdTAXQahrUkfF/6/0sPDiQBjRsZA=";
  };

  dependencies = with python3.pkgs; [
    openai certifi python-dotenv fire httpx rich tenacity pyyaml
    ruamel-yaml requests jinja2 pydantic prompt-toolkit croniter
    packaging markdown pyjwt urllib3 psutil websockets pathspec
    fastapi uvicorn python-multipart ptyprocess pillow
    python-telegram-bot aiohttp slack-sdk
  ];

  meta = with lib; {
    description = "The self-improving AI agent — creates skills from experience";
    homepage = "https://github.com/NousResearch/hermes-agent";
    license = licenses.asl20;
    platforms = platforms.all;
    mainProgram = "hermes";
  };
}
