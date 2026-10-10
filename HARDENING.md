# HARDENING.md

## 1. Problemas encontrados
- `FROM ubuntu:latest` (Dockerfile): imagem grande e sem versão fixa, com mais vulnerabilidades e builds não reproduzíveis.
- `apt-get install nodejs npm` e `COPY . .` (Dockerfile): pacotes e arquivos desnecessários na imagem.
- Sem `USER` (Dockerfile): app rodava como root, então invasão da app daria root no container.
- `ENV DB_PASSWORD=123456` (Dockerfile): senha fraca gravada na imagem e no Git.
- `MYSQL_ROOT_PASSWORD: root` (docker-compose.yml): senha trivial versionada.
- `mysql:latest` (docker-compose.yml): versão não fixa.
- `3306:3306` (docker-compose.yml): banco exposto ao host e à rede.
- Sem limites de CPU/memória: um container pode derrubar o host.
- Sem restrição de capabilities: privilégios desnecessários.

## 2. Medidas aplicadas
- Imagem `node:22.12.0-alpine3.21`: menor, com versão fixa, reduz a superfície de ataque.
- `USER node`: aplicação sem privilégios de administrador.
- Senhas removidas do Dockerfile e do compose e movidas para o `.env`, que está no `.gitignore`.
- `.env.example` criado, só com os nomes das variáveis.
- Banco sem `ports`, em rede `backend` interna: só a app acessa.
- App publicada somente em `127.0.0.1:3000`.
- Limites de CPU e memória em ambos os serviços.
- `cap_drop: ALL`, `no-new-privileges` e filesystem somente leitura na app.
- MySQL com usuário próprio da aplicação, sem usar o root.

## 3. Análise final
1. Principal risco: senhas fracas no código + banco exposto + app rodando como root.
2. Alteração mais importante: fechar a porta do banco e tirar as senhas do código, pois eliminam o acesso mais direto.
3. Se a app fosse comprometida: o atacante teria acesso mínimo, sem root, sem capabilities, com recursos limitados e sem acesso externo ao banco.
4. Menor privilégio: usuário `node`, capabilities removidas, usuário de banco dedicado e rede interna.
5. `.env` fora do Git: contém segredos reais, e o histórico do Git é permanente e visível a quem tiver acesso.
6. `.env.example`: mostra quais variáveis são necessárias, sem os valores.
7. CI/CD: Hadolint (Dockerfile), Trivy (imagem), Gitleaks (segredos) e npm audit/Dependabot.
8. Kubernetes: securityContext, NetworkPolicy, Secrets, limites de recursos, Pod Security Standards e RBAC mínimo.


## 4. Evidências de validação

### 4.1 Build e subida do ambiente
Comando: `docker compose up -d --build`
```
 ✔ Image mysql:8.4.3                     Pulled
 ✔ Image hardening-app:1.0.0             Built
 ✔ Network hardening-container_backend   Created
 ✔ Volume hardening-container_banco_data Created
 ✔ Network hardening-container_frontend  Created
 ✔ Container hardening-container-banco-1 Started
 ✔ Container hardening-container-app-1   Started
```
O build usou a imagem `node:22.12.0-alpine3.21` (versão fixa) e o MySQL `8.4.3`.

### 4.2 Aplicação não roda como root (Etapa 3)
Comando: `docker compose exec app id`
```
uid=1000(node) gid=1000(node) groups=1000(node)
```
A aplicação executa com o usuário `node`, sem privilégios administrativos.

### 4.3 Aplicação continua funcionando
Comando: `curl http://127.0.0.1:3000/`
```
Olá mundo!
```

### 4.4 Exposição de portas (Etapa 5)
Comando: `docker compose ps`
```
NAME                          IMAGE                 COMMAND                  SERVICE   CREATED         STATUS         PORTS
hardening-container-app-1     hardening-app:1.0.0   "docker-entrypoint.s…"   app       3 minutes ago   Up 3 minutes   127.0.0.1:3000->3000/tcp
hardening-container-banco-1   mysql:8.4.3           "docker-entrypoint.s…"   banco     3 minutes ago   Up 3 minutes   3306/tcp, 33060/tcp
```
Somente a aplicação publica porta no host, e apenas em `127.0.0.1`. O banco (`3306/tcp`, `33060/tcp`) não possui mapeamento `->`, ou seja, não está acessível fora da rede interna `backend`. Antes do hardening, o banco era publicado em `3306:3306`.

### 4.5 Limites de recursos (Etapa 6)
Comando: `docker stats --no-stream`
```
CONTAINER ID   NAME                          CPU %     MEM USAGE / LIMIT   MEM %     NET I/O         BLOCK I/O       PIDS
34c33f19b2d4   hardening-container-banco-1   0.33%     483.3MiB / 512MiB   94.39%    1.37kB / 126B   439MB / 556MB   34
f6b9264da0d6   hardening-container-app-1     0.00%     9.082MiB / 256MiB   3.55%     3.53kB / 802B   0B / 0B         7
```
Os limites de memória estão aplicados (512MiB para o banco e 256MiB para a aplicação), assim nenhum container consegue consumir toda a memória do host.
