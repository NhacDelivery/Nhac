"""Fail early when the isolated backend does not support this app's contracts."""

import argparse
import json
import sys
import urllib.error
import urllib.request


def check_backend(port):
    base = f"http://127.0.0.1:{port}/api/v1"

    def request(path, payload=None, token=None):
        headers = {"Content-Type": "application/json"}
        if token:
            headers["Authorization"] = f"Bearer {token}"
        data = json.dumps(payload).encode() if payload is not None else None
        try:
            with urllib.request.urlopen(
                urllib.request.Request(base + path, data=data, headers=headers),
                timeout=10,
            ) as response:
                return json.load(response)
        except urllib.error.HTTPError as error:
            raise RuntimeError(f"{path}: HTTP {error.code}; backend incompatível") from None

    def page(path):
        response = request(path)
        if not isinstance(response, dict) or not isinstance(response.get("content"), list):
            raise RuntimeError(f"{path}: resposta paginada inválida")
        return response["content"]

    products = page("/produtos/cards?lojaId=e2e-loja-001&page=0&size=50&sort=id,asc")
    if not any(product.get("id") == "e2e-produto-001" for product in products):
        raise RuntimeError("/produtos/cards: produto fixture e2e-produto-001 ausente")
    page("/produtos/cards/promocoes?page=0&size=1")
    login = request("/auth/login", {
        "email": "e2e.cliente@nhac.local", "senha": "NhacE2E#123",
    })
    token = login.get("token") if isinstance(login, dict) else None
    if not isinstance(token, str) or not token:
        raise RuntimeError("/auth/login: token da fixture ausente")
    if not isinstance(request("/pedidos/ativos", token=token), list):
        raise RuntimeError("/pedidos/ativos: lista de pedidos inválida")
    feed = request("/feed/posts?page=0&size=1", token=token)
    if not isinstance(feed, dict) or not isinstance(feed.get("content"), list):
        raise RuntimeError("/feed/posts: resposta paginada inválida")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--port", type=int, default=8080)
    port = parser.parse_args().port
    if not 1 <= port <= 65535:
        parser.error("port deve estar entre 1 e 65535")
    try:
        check_backend(port)
    except (RuntimeError, ValueError, urllib.error.URLError) as error:
        print(f"Contrato do backend E2E recusado: {error}", file=sys.stderr)
        return 1
    print("Contratos E2E confirmados: cards, promoções, login, pedidos ativos e feed.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
