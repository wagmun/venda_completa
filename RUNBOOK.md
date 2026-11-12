# RUNBOOK — Venda Completa (fonte única da verdade)

> Este arquivo é a **verdade operacional** do projeto. Qualquer assistente/sessão
> deve **ler este arquivo antes de orientar** e **atualizá-lo + commitar após qualquer
> mudança**. Não confie em memória — confie neste arquivo e na aba **Status** do painel.

Última atualização: 2026-11-12

---

## 1. O mapa — são só 4 peças

```
CELULAR / app   ←→   SERVIDOR (Render)   ←→   BLING
(vendedor; roda       (o "cérebro":            (estoque + nota;
 pelo Android          guarda tudo e            conta do cliente)
 Studio ou APK)        fala com o Bling)
                          ▲
                     PAINEL (/admin)
                   (tela de configuração
                    do servidor)
```

- **App** = ponta do vendedor. Só vende.
- **Servidor (Render)** = cérebro na internet. Não se "loga" nele; ele só roda.
- **Painel** = a página `/admin` do servidor. É onde se configura tudo.
- **Bling** = sistema de estoque/nota do cliente. Externo. Nós só nos conectamos.

---

## 2. Endereços

| O quê | Endereço |
|---|---|
| Servidor (cérebro) | `https://venda-completa-api.onrender.com` |
| Painel (configuração) | `https://venda-completa-api.onrender.com/admin` |
| Versão publicada (checar deploy) | `https://venda-completa-api.onrender.com/version` |
| Saúde do servidor | `https://venda-completa-api.onrender.com/health` |
| Bling (site do cliente) | `https://bling.com.br` |
| Render (publicar o servidor) | `https://dashboard.render.com` |

---

## 3. Registro de LOGINS (qual é qual, e onde usa)

> Regra de ouro: **cada login serve em UM site só.** Não existe login que sirva em dois.
> Senhas aqui são ponteiros (onde achar), não necessariamente o valor em claro.

### Logins do PAINEL (site `/admin`) — um por empresa
| Empresa | Login (e-mail) | Senha | tenant_id |
|---|---|---|---|
| Aion Tecnologia | `admin@aion.com` | **definida no provision; a atual NÃO está confirmada** | `7e564bad-f852-4258-95d9-49363fa24c32` |
| Auto Pecas Veloz (teste) | `admin@autopecas.com` | `123456` | (seed) |
| Oficina Boa (teste) | `admin@oficinaboa.com` | `123456` | (seed) |
| Mercado Central (teste) | `admin@demo.com` | `123456` | (seed) |

### Login do BLING (site `bling.com.br`) — do cliente
- Usuário: **CNPJ** (ex. Aion `69.032.238/0001-03`) **ou o e-mail** da conta Bling.
- Senha: a do Bling (do cliente). Não temos nem alteramos.
- **Se der "usuário ou senha incorretos": é problema da conta Bling** (usuário errado — tentar e-mail no lugar do CNPJ — ou bloqueio por tentativas, ou senha desatualizada). Resolve no Bling (reset) ou com o suporte do Bling. **Nada no nosso sistema consegue afetar isso.**

### Login do VENDEDOR (no app) — criado no painel, aba Vendedores
- Um por vendedor. É o que se digita no app.

> IMPORTANTE: o comando `/provision` e o login do painel **nunca tocam no Bling**.
> São sistemas separados. Um login de um não interfere no outro — o que às vezes
> confunde é o **preenchimento automático do navegador**, que joga a senha de um
> site no campo do outro. Em dúvida, use **janela anônima** e digite à mão.

---

## 4. Estado atual (atualizar a cada mudança)

- **Aion Tecnologia**: criada (tenant acima). Login do painel `admin@aion.com` — **senha a reconfirmar** (o teste de login falhou; recriar com senha simples se necessário).
- **Bling da Aion**: conexão **pendente** — login do Bling está sendo recusado pelo próprio Bling (fora do nosso alcance).
- **Config fiscal (NF-e 55) da Aion**: pendente.
- **Servidor no Render**: deploy do código novo (NF-e 55 + Status) **pendente** — Render com auto-deploy possivelmente desligado. Checar em `/version` se mostra `2026-11-12.1-nfe55`.
- **App (APK)**: `~/Desktop/VendaCompleta.apk` (37 MB) — já com SQLite nativo e impressão Bluetooth.

---

## 5. Procedimento — publicar o servidor (Render)

1. Abrir `https://dashboard.render.com` e logar.
2. Clicar no serviço `venda-completa-api`.
3. Botão **Manual Deploy** (topo direito) → **Deploy latest commit**.
4. Esperar ficar **Live** (2–5 min).
5. Conferir: abrir `https://venda-completa-api.onrender.com/version` e ver se mostra a versão esperada.
6. Settings → Build & Deploy → **Auto-Deploy = Yes** (pra publicar sozinho nos próximos push).

---

## 6. Procedimento — cadastrar uma empresa nova

Comando (terminal). Trocar os dados em MAIÚSCULAS. Evitar `!` na senha.
```
curl -X POST https://venda-completa-api.onrender.com/provision \
  -H "X-Platform-Key: Pwu8ldKq5ed5VTzM-i1_mYMCPVe3GJY2oYwygmKaZvc" \
  -H "Content-Type: application/json" \
  -d '{"razao_social":"NOME","cnpj":"SONUMEROS","uf":"UF","inscricao_estadual":"ISENTO","admin_email":"admin@EMPRESA.com","admin_senha":"SENHASIMPLES"}'
```
Resposta `201` = criada. `409` = já existe. Anotar o login no item 3 deste arquivo.

---

## 7. Procedimento — rodar um teste (1 ação por linha)

Papéis: **[Aion]** = quem configura (você/vendedor do app) · **[cliente]** = quem compra/usa o app e é dono do Bling.
Ordem importa: **sincronizar estoque vem logo após conectar o Bling**; **config fiscal fica antes da 1ª venda** (natureza de operação só importa na hora da nota, não no espelhamento do estoque).

1. [Aion] Painel `/admin` → logar como admin da empresa → aba **Status** confirma empresa/CNPJ.
2. [Aion] Aba **Bling** → **Conectar ao Bling** (ou **Copiar link para o cliente** e enviar).
3. [cliente] Na tela do Bling, logar (CNPJ **ou** e-mail) e **Autorizar**.
4. [Aion] Confirmar "conectado" (aba Bling ou Status).
5. [Aion] **Sincronizar estoque agora** → puxa os produtos do Bling.
6. [Aion] Aba **Vendedores** → criar o login do vendedor (login do app).
7. [Aion] **Configuração fiscal** → **Carregar do Bling** → natureza de operação de venda + forma de pagamento do boleto → **Salvar**. (O CFOP/imposto por produto o Bling resolve da ficha do produto; aqui é só a natureza padrão de venda.)
8. [cliente] Instalar o APK no celular; parear a impressora Bluetooth.
9. [cliente] App → entrar como vendedor → vender → NF-e 55 + boleto → "Abrir DANFE" / imprimir "Comprovante".

Entre cada passo, conferir na aba **Status** se o estado mudou como esperado.

---

## 8. Regras de operação (para o assistente)

1. **Ler este RUNBOOK antes de orientar.** Não assumir estado de memória.
2. **Verificar o estado real** (endpoint `/admin/status` ou a aba Status) antes de instruir.
3. **1 ação por vez**; só avançar com o "ok" do usuário.
4. **Toda mudança termina atualizando este arquivo + commit.**
5. Ao bumpar o servidor, alterar `kServerVersion` em `server/bin/server.dart`.
