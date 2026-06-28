-- Migração: Adicionar campos de prazo limite para wishlist
-- Execute este script no seu banco de dados PostgreSQL

-- Adiciona coluna expirado (indica se o prazo passou sem atingir o alvo)
ALTER TABLE wishlist_itens 
ADD COLUMN IF NOT EXISTS expirado BOOLEAN NOT NULL DEFAULT FALSE;

-- Adiciona coluna data_limite (prazo máximo para monitoramento)
ALTER TABLE wishlist_itens 
ADD COLUMN IF NOT EXISTS data_limite TIMESTAMP WITH TIME ZONE;

-- Comentários para documentação
COMMENT ON COLUMN wishlist_itens.expirado IS 'Indica se o prazo de monitoramento expirou sem atingir o preço-alvo';
COMMENT ON COLUMN wishlist_itens.data_limite IS 'Data/hora limite para o monitoramento da ação';

