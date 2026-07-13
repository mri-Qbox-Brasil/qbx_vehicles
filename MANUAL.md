# Manual do qbx_vehicles

API de gerenciamento de veículos do jogador para Qbox — recurso servidor que fornece API abrangente para gerenciar veículos próprios com persistência em banco de dados.

## Funcionalidades Principais

### Gerenciamento de Veículos
- **Criação**: Criar novos veículos com geração automática de placa
- **Pesquisa**: Obter veículos por ID, citizen ID, licença ou placa
- **Transferência**: Alterar propriedade entre jogadores
- **Exclusão**: Deletar veículos por múltiplos critérios
- **Salvamento**: Salvar estado, props, garagem e danos

### Controle de Estado
- **OUT**: Veículo fora da garagem (em uso)
- **GARAGED**: Veículo na garagem
- **IMPOUNDED**: Veículo apreendido

### Recursos Avançados
- **Preços de Depósito**: Definir preços personalizados para veículos apreendidos
- **Hooks**: Sistema de eventos para criar, salvar e alterar propriedade
- **Validação de Placa**: Garante placas exclusivas automaticamente

## Configuração

Este é um recurso apenas do servidor (sem scripts do cliente). A configuração é feita via API e banco de dados.

### Esquema do Banco de Dados

Tabela `player_vehicles`:

| Coluna | Tipo | Descrição |
|--------|------|-------------|
| `id` | INT (PK) | ID do veículo |
| `citizenid` | VARCHAR | ID do cidadao do proprietário |
| `license` | VARCHAR | Licença do proprietário |
| `vehicle` | VARCHAR | Nome do modelo |
| `hash` | BIGINT | Hash do modelo |
| `mods` | JSON | Propriedades do veículo |
| `plate` | VARCHAR | Placa de licença |
| `state` | INT | Estado (0=OUT, 1=GARAGED, 2=IMPOUNDED) |
| `garage` | VARCHAR | Garagem atual |
| `depotprice` | INT | Preço de apreensão |
| `fuel` | FLOAT | Nível de combustível |
| `engine` | FLOAT | Saúde do motor |
| `body` | FLOAT | Saúde da carroceria |

## Exports (API)

### Server Exports

| Exportação | Parâmetros | Retorno | Descrição |
|--------|------------|--------|-------------|
| `CreatePlayerVehicle` | `request` | `integer? vehicleId, ErrorResult?` | Criar veículo |
| `GetPlayerVehicle` | `vehicleId, filters?` | `PlayerVehicle?` | Obter veículo específico |
| `GetPlayerVehicles` | `filters?` | `PlayerVehicle[]` | Obter veículos |
| `SetPlayerVehicleOwner` | `vehicleId, citizenid` | `boolean, ErrorResult?` | Transferir propriedade |
| `DeletePlayerVehicles` | `idType, idValue` | `boolean` | Excluir veículo(s) |
| `GetVehicleIdByPlate` | `plate` | `integer?` | Encontrar ID por placa |
| `SaveVehicle` | `vehicle, options` | `boolean, ErrorResult?` | Salvar estado |
| `DoesPlayerVehiclePlateExist` | `plate` | `boolean` | Verificar se placa existe |

### Estruturas de Dados

#### CreatePlayerVehicleRequest
```lua
---@class CreatePlayerVehicleRequest
---@field model string           # Nome do modelo
---@field citizenid? string      # ID do cidadao
---@field garage? string         # Nome da garagem
---@field props? table            # Propriedades ox_lib
```

#### PlayerVehicle
```lua
---@class PlayerVehicle
---@field id number              # ID do banco de dados
---@field citizenid? string       # ID do cidadao
---@field modelName string       # Nome do modelo
---@field garage string          # Garagem atual
---@field state State            # Estado (0=OUT, 1=GARAGED, 2=IMPOUNDED)
---@field depotPrice integer     # Preço do depósito
---@field props table             # Propriedades ox_lib
```

#### PlayerVehiclesFilters
```lua
---@class PlayerVehiclesFilters
---@field citizenid? string      # Filtrar por proprietário
---@field states? State|State[] # Filtrar por estado(s)
---@field garage? string         # Filtrar por garagem
```

## Eventos

| Evento | Payload | Descrição |
|-------|----------|-------------|
| `qbx_vehicles:server:vehicleSaved` | `vehicleId` | Veículo salvo |
| `qbx_vehicles:server:vehicleCreated` | `vehicleId, citizenid` | Veículo criado |
| `qbx_vehicles:server:ownerChanged` | `vehicleId, oldCitizenId, newCitizenId` | Propriedade alterada |

## Sistema de Hooks

O recurso suporta hooks via sistema do qbx_core:

| Nome do Hook | Dados | Descrição |
|-----------|------|-------------|
| `createPlayerVehicle` | `{citizenid, garage, props}` | Antes da criação |
| `changeVehicleOwner` | `{vehicleId, newCitizenId}` | Antes da alteração |
| `saveVehicle` | `{vehicleId, options}` | Antes do salvamento |

### Exemplo de Hook
```lua
-- Cancelar criação de veículo
AddEventHandler('qbx_vehicles:hook:createPlayerVehicle', function(data)
    if data.citizenid == 'BANNED123' then
        CancelEvent()
    end
end)
```

## Exemplos de Uso

### Criando um Veículo
```lua
local vehicleId, err = exports.qbx_vehicles:CreatePlayerVehicle({
    model = 'adder',
    citizenid = 'CIT12345',
    garage = 'pillbox_garage',
    props = {
        plate = 'ABC123',
        fuelLevel = 100,
        engineHealth = 1000,
        bodyHealth = 1000
    }
})

if vehicleId then
    print('Veículo criado com ID:', vehicleId)
else
    print('Erro:', err.message)
end
```

### Obtendo Veículos do Jogador
```lua
-- Todos os veículos
local vehicles = exports.qbx_vehicles:GetPlayerVehicles({
    citizenid = 'CIT12345'
})

-- Apenas na garagem
local garaged = exports.qbx_vehicles:GetPlayerVehicles({
    citizenid = 'CIT12345',
    states = 1 -- GARAGED
})

-- Veículo específico
local vehicle = exports.qbx_vehicles:GetPlayerVehicle(123)
```

### Transferindo Propriedade
```lua
local success, err = exports.qbx_vehicles:SetPlayerVehicleOwner(123, 'CIT67890')
if success then
    print('Propriedade transferida!')
end
```

### Salvando Estado do Veículo
```lua
local vehicle = GetVehiclePedIsIn(ped, false)
local success = exports.qbx_vehicles:SaveVehicle(vehicle, {
    state = 1, -- GARAGED
    garage = 'pillbox_garage',
    props = lib.getVehicleProperties(vehicle)
})
```

### Deletando Veículos
```lua
-- Por citizenid
exports.qbx_vehicles:DeletePlayerVehicles('citizenid', 'CIT12345')

-- Por placa
exports.qbx_vehicles:DeletePlayerVehicles('plate', 'ABC123')

-- Por ID do veículo
exports.qbx_vehicles:DeletePlayerVehicles('id', 123)
```

## Estrutura de Arquivos

```
qbx_vehicles/
├── server/
│   ├── main.lua           # API principal, CRUD, exports
│   └── storage.lua         # Consultas de banco de dados
└── fxmanifest.lua
```

## Dependências

| Dependência | Versão Mínima | Obrigatório |
|------------|-------------------|----------|
| ox_lib | - | ✅ |
| oxmysql | - | ✅ |
| qbx_core | 1.2.0 | ✅ |

## Notas Importantes

- Este é um recurso **apenas do servidor** (sem scripts do cliente)
- Placas são geradas automaticamente se não fornecidas
- Placas são garantidamente exclusivas antes da atribuição
- Todas as alterações de estado devem passar pela API para consistência
- O recurso integra com `qbx_core` para validação do jogador
- A tabela do banco de dados é criada automaticamente na inicialização

## Solução de Problemas

### Veículo não é criado
- Verifique se o citizenid existe
- Confirme que o modelo do veículo é válido
- Verifique se a placa não está duplicada
- Veja erros retornados na variável `err`

### Veículo não salva
- Confirme que o veículo tem um ID válido
- Verifique se as propriedades estão no formato ox_lib
- Confirme que o veículo está em um estado válido

### Transferência falha
- Verifique se o novo citizenid existe
- Confirme que o vehicleId é válido
- Verifique se o veículo não está apreendido (se houver restrição)

### Placa duplicada
- O sistema valida automaticamente antes de atribuir
- Se ocorrer, verifique a função `DoesPlayerVehiclePlateExist`
- Gere uma nova placa manualmente se necessário
