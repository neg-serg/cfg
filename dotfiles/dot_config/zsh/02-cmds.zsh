_exists rg && alias zrg="rg -z"

_exists sudo && {
    local sudo_list=(chmod chown modprobe umount)
    for c in ${sudo_list[@]}; {_exists "$c" && alias "$c=sudo $c"}
}
_exists journalctl && journalctl() {command journalctl "${@:--b}";}
_exists mpc && {
    cdm(){
        dirname="$XDG_MUSIC_DIR/$(dirname "$(mpc -f '%file%'|head -1)")"
        cd "$dirname"
    }
}
_exists curl && {
    geoip(){ curl ipinfo.io/$1; }
    sprunge(){ curl -F "file=@${1:--}" https://0x0.st; }
}
_exists flatpak && {
    flatpak(){
        if curl --socks5 127.0.0.1:10808 --max-time 1 -s https://flathub.org >/dev/null 2>&1; then
            https_proxy=socks5://127.0.0.1:10808 command flatpak "$@"
        else
            command flatpak "$@"
        fi
    }
}
_exists broot && autoload -Uz br

autoload zc

# vim: ft=zsh:nowrap
