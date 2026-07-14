# qbx_vehicles — Manual

Camada de acesso à tabela `player_vehicles`: um recurso server-only, sem UI e sem comandos, que expõe exports de CRUD de veículos de jogador para os demais recursos do Qbox (garagens, concessionárias, depósito).

---

## Sumário

1. [Dependências](#dependências)
2. [Instalação](#instalação)
3. [Banco de dados](#banco-de-dados)
4. [Estados do veículo](#estados-do-veículo)
5. [Entrypoints para outros recursos](#entrypoints-para-outros-recursos)
6. [Event hooks](#event-hooks)
7. [Eventos emitidos](#eventos-emitidos)
8. [Estrutura de arquivos](#estrutura-de-arquivos)

---

## Dependências

| Recurso | Obrigatório | Observação |
|---|---|---|
| `qbx_core` | Sim | Versão mínima **1.2.0**, validada em runtime por `lib.checkDependency`. Fornece `qbx.generateRandomPlate`, `qbx.string.trim` e o módulo de hooks |
| `ox_lib` | Sim | `lib.checkDependency`, `lib.versionCheck`, `lib.print.debug` |
| `oxmysql` | Sim | Todo o recurso é acesso à tabela `player_vehicles` |

O recurso é declarado `server_only 'yes'` — não carrega nada no client.

---

## Instalação

1. Copie a pasta `qbx_vehicles` para `resources/`.
2. Importe o `vehicles.sql` no banco. Ele cria a tabela `player_vehicles` com chaves estrangeiras para `players`, então o SQL do `qbx_core` precisa ter rodado antes.
3. Adicione ao `server.cfg`, **antes** dos recursos que dependem dele (garagens, `qbx_vehicleshop`):
   ```
   ensure qbx_vehicles
   ```
4. **Conflitos** — não rode junto com outro recurso que gerencie a tabela `player_vehicles` por conta própria. Recursos legados que fazem `INSERT`/`UPDATE` direto na tabela continuam funcionando, mas escapam dos event hooks descritos abaixo.

No boot, o recurso valida a versão do `qbx_core` e consulta o repositório (`lib.versionCheck`) para avisar sobre releases mais novas.

---

## Banco de dados

Tabela `player_vehicles`, criada por `vehicles.sql`:

| Coluna | Tipo | Descrição |
|---|---|---|
| `id` | int, PK, auto | Identificador do veículo. É o `vehicleId` usado por todos os exports |
| `license` | varchar(50) | Licença do dono. Preenchida automaticamente a partir do `citizenid`. FK para `players` |
| `citizenid` | varchar(50) | Dono do veículo. FK para `players`, com `ON DELETE CASCADE` |
| `vehicle` | varchar(50) | Nome do modelo (spawn name) |
| `hash` | varchar(50) | Hash `joaat` do modelo |
| `mods` | longtext | Tabela de propriedades do `ox_lib` serializada em JSON. É a fonte da verdade das props |
| `plate` | varchar(15), único | Placa |
| `garage` | varchar(50) | Garagem onde o veículo está guardado |
| `fuel` | int | Espelho de `props.fuelLevel` |
| `engine` | float | Espelho de `props.engineHealth` |
| `body` | float | Espelho de `props.bodyHealth` |
| `state` | int | Estado do veículo. Ver a tabela abaixo |
| `depotprice` | int | Valor a pagar para retirar o veículo do depósito |
| `fakeplate` | varchar(50) | Coluna legada. O `qbx_vehicles` não lê nem escreve nela |
| `drivingdistance` | int | Coluna legada. O `qbx_vehicles` não lê nem escreve nela |
| `status` | text | Coluna legada. O `qbx_vehicles` não lê nem escreve nela |

As colunas espelho `fuel`, `engine` e `body` só são atualizadas por `SaveVehicle` quando o campo correspondente existe em `props`. Elas existem para compatibilidade com recursos que leem a tabela direto.

---

## Estados do veículo

A coluna `state` usa a enum interna:

| Valor | Nome | Significado |
|---|---|---|
| `0` | `OUT` | Veículo fora da garagem, no mundo |
| `1` | `GARAGED` | Guardado em uma garagem |
| `2` | `IMPOUNDED` | Apreendido no depósito |

`CreatePlayerVehicle` grava `GARAGED` quando a request traz `garage`, e `OUT` caso contrário.

---

## Entrypoints para outros recursos

Todos os exports são de servidor.

### GetPlayerVehicles

Retorna a lista de veículos que batem com os filtros. Sem filtros, retorna todos.

```lua
local vehicles = exports.qbx_vehicles:GetPlayerVehicles({
    citizenid = 'ABC12345',   -- opcional
    garage = 'pillboxgarage', -- opcional
    states = 1                -- opcional: um estado ou um array de estados
})
```

Cada item da lista tem o formato:

```lua
{
    id = 12,                  -- vehicleId
    citizenid = 'ABC12345',
    modelName = 'sultan',
    garage = 'pillboxgarage',
    state = 1,
    depotPrice = 0,
    props = { ... }           -- tabela de props do ox_lib, já decodificada
}
```

Passar `states` como array (`{0, 2}`) monta um `OR` entre os estados.

### GetPlayerVehicle

Retorna um único veículo pelo `vehicleId`. Aceita os mesmos filtros como restrição adicional — útil para confirmar posse antes de agir.

```lua
local vehicle = exports.qbx_vehicles:GetPlayerVehicle(vehicleId, { citizenid = 'ABC12345' })
```

Retorna `nil` se nenhum veículo bater com os filtros.

### CreatePlayerVehicle

Insere um veículo novo e devolve o `vehicleId`.

```lua
local vehicleId, err = exports.qbx_vehicles:CreatePlayerVehicle({
    model = 'sultan',             -- obrigatório
    citizenid = 'ABC12345',       -- opcional; sem ele o veículo fica sem dono
    garage = 'pillboxgarage',     -- opcional; presente, define o state como GARAGED
    props = { plate = 'ABC 123' } -- opcional
})
```

Sem `props.plate`, uma placa aleatória é gerada e testada contra o banco até ser única. Os campos `engineHealth`, `bodyHealth` e `fuelLevel` recebem os padrões 1000, 1000 e 100 quando ausentes. `props.model` é sempre sobrescrito com o `joaat` do modelo.

Se um hook `createPlayerVehicle` cancelar a operação, o retorno é `nil` mais um `ErrorResult` com `code = 'hook_cancelled'`.

### SetPlayerVehicleOwner

Troca o dono do veículo. A `license` é atualizada junto, derivada do novo `citizenid`.

```lua
local success, err = exports.qbx_vehicles:SetPlayerVehicleOwner(vehicleId, 'DEF67890')
```

Omitir o `citizenid` deixa o veículo sem dono. Cancelável pelo hook `changeVehicleOwner`.

### DeletePlayerVehicles

Apaga veículos por um dos quatro tipos de identificador.

```lua
exports.qbx_vehicles:DeletePlayerVehicles('vehicleId', 12)
exports.qbx_vehicles:DeletePlayerVehicles('citizenid', 'ABC12345')
exports.qbx_vehicles:DeletePlayerVehicles('license', 'license:abc...')
exports.qbx_vehicles:DeletePlayerVehicles('plate', 'ABC 123')
```

Um `idType` fora desses quatro dispara `assert` e derruba a chamada. Usar `citizenid` ou `license` apaga **todos** os veículos do jogador.

### SaveVehicle

Persiste alterações de um veículo existente, a partir da entidade no mundo.

```lua
local success, err = exports.qbx_vehicles:SaveVehicle(vehicleEntity, {
    garage = 'pillboxgarage',             -- opcional
    state = 1,                            -- opcional
    depotPrice = 500,                     -- opcional
    props = lib.getVehicleProperties(veh) -- opcional
})
```

O `vehicleId` é resolvido pelo statebag `Entity(vehicle).state.vehicleid` e, na falta dele, pela placa. Se o veículo não estiver na tabela, o retorno é `false` mais um `ErrorResult` com `code = 'not_owned'`.

Ao passar `props`, as colunas espelho `plate`, `fuel`, `engine` e `body` são atualizadas junto com o `mods`.

### GetVehicleIdByPlate

```lua
local vehicleId = exports.qbx_vehicles:GetVehicleIdByPlate('ABC 123')
```

A placa passa por `trim` antes da consulta. Retorna `nil` se não existir.

### DoesPlayerVehiclePlateExist

```lua
local exists = exports.qbx_vehicles:DoesPlayerVehiclePlateExist('ABC 123')
```

---

## Event hooks

Duas operações passam pelo módulo de hooks do `qbx_core`. Um hook que retorne `false` cancela a operação, e o export devolve `code = 'hook_cancelled'`.

### createPlayerVehicle

Disparado antes do `INSERT`. Payload: `citizenid`, `garage`, `props`.

```lua
local registerHook = require '@qbx_core.modules.hooks'

registerHook('createPlayerVehicle', function(payload)
    -- payload.citizenid, payload.garage, payload.props
    if payload.props.model == joaat('adder') then
        return false -- bloqueia a criação
    end
end)
```

### changeVehicleOwner

Disparado antes do `UPDATE` de dono. Payload: `vehicleId`, `newCitizenId`.

```lua
registerHook('changeVehicleOwner', function(payload)
    -- payload.vehicleId, payload.newCitizenId
end)
```

---

## Eventos emitidos

### qbx_vehicles:server:vehicleSaved

Disparado no servidor sempre que `SaveVehicle` completa com sucesso.

```lua
AddEventHandler('qbx_vehicles:server:vehicleSaved', function(vehicleId)
    -- vehicleId salvo
end)
```

---

## Estrutura de arquivos

```
qbx_vehicles/
├── server/
│   └── main.lua          — exports de CRUD, event hooks e evento vehicleSaved
├── vehicles.sql          — schema da tabela player_vehicles
└── fxmanifest.lua        — declara o recurso como server_only
```
