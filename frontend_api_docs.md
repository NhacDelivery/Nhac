# Documentação de Integração - Backend Nhac (Para o Agent do Frontend)

Esta documentação detalha os endpoints solicitados para a integração com o Frontend. Todos os endpoints exigem que os dados sigam os padrões descritos, pois falhas nas validações (`jakarta.validation`) retornarão HTTP 400.

## 1. Checar E-mail
Verifica se um e-mail já existe na base de dados (útil para redirecionar o fluxo de login ou cadastro).

* **URL:** `POST /api/v1/auth/checar-email`
* **Autenticação:** Não requer token.
* **Payload (JSON):**
```json
{
  "email": "usuario@exemplo.com"
}
```
* **Regras do Payload:**
  - `email`: Não pode ser vazio e deve possuir um formato de e-mail válido (contendo `@`, domínio, etc.).
* **Resposta Esperada (200 OK):**
```json
{
  "existe": true
}
```

---

## 2. Atualizar Dados do Usuário
Usado para atualizar informações de perfil, como o telefone.

* **URL:** `PUT /api/v1/usuarios/{id}` (Substituir `{id}` pelo UUID real do usuário)
* **Autenticação:** Requer Token JWT no header `Authorization: Bearer <token>`. O usuário logado só pode alterar o próprio ID.
* **Payload (JSON):** Todos os campos são opcionais e apenas os preenchidos serão atualizados.
```json
{
  "nome": "João Silva",
  "email": "joao@exemplo.com",
  "telefone": "11988887777",
  "imagemUrl": "https://img.com/foto.jpg",
  "fcmToken": "token-firebase-device"
}
```
* **Regras do Payload:**
  - `email`: Se enviado, deve ser um formato válido de e-mail.
  - `telefone`: Máximo de 20 caracteres. O backend aceita sem formatação aqui (ex: numérico `11988887777`), mas para a validação de SMS exigiremos o código E.164.

---

## 3. Enviar Código SMS (OTP)
Envia o código de 6 dígitos para o celular do usuário via Twilio.

> [!IMPORTANT]
> **Formato de Telefone Obrigatório**
> O telefone para as rotas de SMS deve **OBRIGATORIAMENTE** usar o formato internacional `E.164`. O regex validado no backend é: `^\+[1-9]\d{1,14}$`.
> Exemplo correto para o Brasil: `+55` (País) `11` (DDD) `988887777` (Número) -> `+5511988887777`.

* **URL:** `POST /api/v1/verificacao-telefone/enviar-codigo`
* **Autenticação:** Não requer token (livre, mas o ideal é que seja atrelado ao fluxo).
* **Payload (JSON):**
```json
{
  "telefone": "+5511999999999"
}
```
* **Resposta Esperada (200 OK):** Corpo vazio.

---

## 4. Validar Código SMS (OTP)
Compara o código digitado com o gerado. Tem limite de 3 tentativas e os códigos expiram em 5 minutos. Se o código for correto, o backend marca a flag `telefoneVerificado = true` no banco para este usuário automaticamente.

* **URL:** `POST /api/v1/verificacao-telefone/validar-codigo`
* **Autenticação:** Não requer token para validação.
* **Payload (JSON):**
```json
{
  "telefone": "+5511999999999",
  "codigo": "123456"
}
```
* **Regras do Payload:**
  - `telefone`: Formato E.164 obrigatório (`+5511999999999`).
  - `codigo`: Deve conter exatamente **6 dígitos** (String de tamanho 6).
* **Respostas Possíveis:**
  - **200 OK:** Código válido, usuário teve o telefone confirmado no BD.
  - **400 Bad Request:** Formato de telefone errado ou código com menos/mais de 6 caracteres.
  - **400 Bad Request (Regra de Negócio):** O retorno trará um `ErroPadraoDTO` padrão do nosso `ResourceExceptionHandler` com as seguintes mensagens de erro para o frontend exibir:
    - *"Código expirado ou não encontrado. Solicite um novo código."*
    - *"Limite de tentativas excedido para este código. Solicite um novo."*
    - *"Código de verificação inválido."*

## Validar código de recuperação de senha

* **URL:** `POST /api/v1/auth/validar-codigo-redefinicao/email`
* **Autenticação:** Não requer token.
* **Payload:** `{"email":"usuario@exemplo.com","codigo":"123456"}`
* **200 OK:** Corpo vazio. O código está válido e ainda pode ser usado para redefinir a senha.
* **400:** Email/código malformado, código incorreto, expirado ou limite de tentativas excedido.

A tela de código só deve avançar após o HTTP 200. Essa consulta não consome o
código nem estende sua validade. `POST /api/v1/auth/redefinir-senha/email`
continua conferindo o código e consumindo-o na redefinição. Ambas as etapas usam
somente códigos `RESET_SENHA`, com validade de 15 minutos e limite de 3 erros.
O backend com essa nova rota deve ser publicado antes do app que a utiliza.

## Cupons de boas-vindas

Todas as rotas abaixo exigem o JWT do cliente. O dono do cupom vem da sessão;
o aplicativo não envia um ID de usuário.

- `GET /api/v1/cupons`: lista os cupons da conta, com status `DISPONIVEL`, `USADO` ou `EXPIRADO`.
- `POST /api/v1/cupons/boas-vindas`: recebe o cupom uma vez por conta. Repetir a chamada retorna o mesmo cupom sem renovar a validade.
- `POST /api/v1/cupons/validar`, JSON `{"cupomId":"uuid","subtotal":30}`: valida uma prévia e retorna `descontoAplicado`, sem consumir o cupom.
- `POST /api/v1/pedidos`: recebe `cupomId` opcional, recalcula o subtotal pelos preços do banco e aplica o desconto na mesma transação do pedido.

O padrão inicial é R$ 5 sobre produtos a partir de R$ 25, válido por 30 dias a
partir do resgate. O frete não recebe desconto. As propriedades do backend são
`nhac.cupom.boas-vindas.valor`, `nhac.cupom.boas-vindas.minimo` e
`nhac.cupom.boas-vindas.validade-dias`. Mudanças afetam apenas novos resgates.
O mínimo precisa ser maior que o desconto e os valores precisam ser positivos.

O cupom é reservado quando o pedido é criado. Um replay com a mesma chave de
idempotência não o consome novamente. Falhas transacionais de criação/pagamento
revertem o uso; cancelar o pedido o libera, mantendo a validade original.
O banco precisa da migração `V1003__cupons_boas_vindas.sql` antes do novo app.

## Sessões e pagamentos

Perfil e endereços são limpos quando muda a conta; respostas de consultas da
sessão anterior são descartadas. O carrinho local é separado por conta e limpo
no logout manual ou automático. Senhas são enviadas sem remover espaços.
A página de formas de pagamento informa as opções disponíveis no checkout;
o cadastro de cartões salvos pelo perfil continua indisponível e não apresenta
mais uma ação de cadastro que simula sucesso.
