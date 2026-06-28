import os
import asyncio
import httpx
from decimal import Decimal
from typing import Optional
from datetime import datetime, timezone

from fastapi import FastAPI
from sqlalchemy.orm import Session
from sqlalchemy import and_, or_

from ..database import SessionLocal
from ..models.wishlist_item import WishlistItem
from ..events.mq import publish_notification


async def fetch_asset_price(symbol: str, client: Optional[httpx.AsyncClient] = None) -> Optional[Decimal]:
    token = os.getenv("FINNHUB_TOKEN", "")
    if not token:
        return None
    url = f"https://finnhub.io/api/v1/quote?symbol={symbol}&token={token}"

    # Backoff simples para 429/5xx
    max_retries = 3
    delay = 1.0

    for attempt in range(max_retries):
        try:
            if client is None:
                async with httpx.AsyncClient(timeout=10) as temp_client:
                    resp = await temp_client.get(url)
            else:
                resp = await client.get(url)

            if resp.status_code == 200:
                data = resp.json()
                current = data.get("c")
                if current is None:
                    return None
                return Decimal(str(current))

            # Em 429/5xx, aplica backoff e tenta novamente
            if resp.status_code == 429 or 500 <= resp.status_code < 600:
                await asyncio.sleep(delay)
                delay *= 2
                continue

            # Outros status: não tentar novamente
            return None
        except Exception:
            # Erros de rede: tenta novamente com backoff
            await asyncio.sleep(delay)
            delay *= 2
            continue

    return None


async def start_wishlist_price_checker(app: FastAPI, interval_seconds: int = 600) -> None:
    """Loop em background que checa preços de itens da wishlist e dispara notificação quando atingir o alvo ou expirar."""
    async with httpx.AsyncClient(timeout=10) as client:
        while True:
            db: Session = SessionLocal()
            try:
                now = datetime.now(timezone.utc)
                
                # Busca itens ativos (não atingidos e não expirados)
                itens = (
                    db.query(WishlistItem)
                    .filter(
                        WishlistItem.atingido == False,
                        WishlistItem.expirado == False,
                        WishlistItem.provider == "FINNHUB"
                    )
                    .all()
                )
                
                for item in itens:
                    # Verifica se o prazo expirou
                    if item.data_limite is not None:
                        # Garante que ambos os datetimes têm timezone para comparação
                        data_limite = item.data_limite
                        if data_limite.tzinfo is None:
                            data_limite = data_limite.replace(tzinfo=timezone.utc)
                        
                        if now >= data_limite:
                            # Prazo expirou - marca como expirado e notifica
                            item.expirado = True
                            
                            # Busca o preço atual uma última vez
                            price = await fetch_asset_price(item.symbol, client=client)
                            if price is not None:
                                item.preco_atual = price
                            
                            payload = {
                                "tipo": "prazo_expirado",
                                "grupo_id": str(item.grupo_id),
                                "symbol": item.symbol,
                                "titulo": item.titulo,
                                "preco_alvo": str(item.preco_alvo),
                                "preco_atual": str(item.preco_atual) if item.preco_atual else None,
                                "data_limite": item.data_limite.isoformat(),
                                "provider": "FINNHUB",
                                "mensagem": f"⏰ Prazo expirado! A ação {item.symbol} não atingiu o preço-alvo de ${item.preco_alvo}",
                            }
                            routing = f"notificacao.wishlist.prazo_expirado.{item.grupo_id}"
                            await publish_notification(app, routing_key=routing, payload=payload)
                            continue
                    
                    # Busca preço atual
                    price = await fetch_asset_price(item.symbol, client=client)
                    if price is None:
                        continue

                    item.preco_atual = price

                    # Verifica se atingiu o preço-alvo
                    if price <= item.preco_alvo:
                        item.atingido = True
                        payload = {
                            "tipo": "preco_atingido",
                            "grupo_id": str(item.grupo_id),
                            "symbol": item.symbol,
                            "titulo": item.titulo,
                            "preco_alvo": str(item.preco_alvo),
                            "preco_atual": str(price),
                            "provider": "FINNHUB",
                            "mensagem": f"🎯 Preço-alvo atingido! {item.symbol} está em ${price}",
                        }
                        routing = f"notificacao.wishlist.preco_atingido.{item.grupo_id}"
                        await publish_notification(app, routing_key=routing, payload=payload)

                db.commit()
            except Exception as e:
                print(f"Erro no wishlist_price_checker: {e}")
                try:
                    db.rollback()
                except Exception:
                    pass
            finally:
                db.close()

            await asyncio.sleep(interval_seconds)