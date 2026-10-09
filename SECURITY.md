# Security

Auralis é software proprietário.

## Segredos e credenciais

O repositório não deve conter chaves de API, senhas, tokens, certificados privados, chaves de assinatura, dados pessoais ou conteúdo de bibliotecas de usuários.

Credenciais opcionais de serviços externos devem ser fornecidas em tempo de execução ou armazenadas como secrets do provedor de CI. Nunca devem ser adicionadas ao código-fonte.

## Dados locais

Biblioteca, progresso, configurações e traduções em cache são armazenados localmente no dispositivo do usuário.

## Relato de falhas

Não publique credenciais, dados privados ou arquivos de usuários em issues públicas. Falhas devem ser reproduzidas com conteúdo de teste não sensível.
