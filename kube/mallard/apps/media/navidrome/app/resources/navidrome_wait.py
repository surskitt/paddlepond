#!/usr/bin/env python

import argparse
import json
import logging
import os
import socket
import time
import urllib.parse
import urllib.request


class EnvDefault(argparse.Action):
    def __init__(self, envvar, required=True, default=None, **kwargs):
        if envvar:
            if envvar in os.environ:
                default = os.environ[envvar]
        if required and (default is not None):
            required = False
        super(EnvDefault, self).__init__(default=default, required=required, **kwargs)

    def __call__(self, parser, namespace, values, option_string=None):
        setattr(namespace, self.dest, values)


def parse_args():
    parser = argparse.ArgumentParser(
        prog="navidrome_queue_to_playlist",
        description="Create playlist from navidrome queue",
    )
    parser.add_argument("-U", "--url", action=EnvDefault, envvar="URL")
    parser.add_argument("-u", "--username", action=EnvDefault, envvar="USERNAME")
    parser.add_argument("-p", "--password", action=EnvDefault, envvar="PASSWORD")

    return parser.parse_args()


def navidrome_request(url, endpoint, username, password, **extra):
    params = {
        "u": username,
        "p": password,
        "v": "1.16.1",
        "c": "queue2pl",
        "f": "json",
    } | extra
    url_params = urllib.parse.urlencode(params, doseq=True)
    url = f"{url}/rest/{endpoint}?{url_params}"

    with urllib.request.urlopen(url) as req:
        j = json.loads(req.read())
        return j["subsonic-response"]


def main():
    logging.basicConfig(
        level=logging.INFO, format="%(asctime)s - %(levelname)s - %(message)s"
    )

    args = parse_args()

    logging.info("Waiting 30 seconds before starting")
    time.sleep(30)

    urlsplit = urllib.parse.urlsplit(args.url)
    host = urlsplit.hostname
    port = urlsplit.port or (443 if urlsplit.scheme == "https" else 80)

    logging.info(f"Waiting for connection to {host}:{port}")
    sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    sock.settimeout(5)
    navidrome_open = sock.connect_ex((host, port))

    while navidrome_open != 0:
        logging.info(f"{host}:{port} not open, retrying")
        time.sleep(5)

        sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        sock.settimeout(5)
        navidrome_open = sock.connect_ex((host, port))

    logging.info("Waiting for navidrome to be ready")
    navidrome_status = navidrome_request(args.url, "ping", args.username, args.password)
    while navidrome_status["status"] != "ok":
        time.sleep(10)
        navidrome_status = navidrome_request(
            args.url, "ping", args.username, args.password
        )

    logging.info("Navidrome ready!")


if __name__ == "__main__":
    main()
