# Release notes

## 2.1.0

- Novo modo **Natural** recomendado no Android: prioriza Google Speech Services e as vozes de maior qualidade disponíveis no aparelho.
- Seleção de voz corrigida para favorecer qualidade HIGH/VERY_HIGH e vozes neurais/online quando disponíveis.
- Acompanhamento **palavra a palavra** usando os offsets nativos do Android TTS.
- Nova interface de leitura com cartão “Ouvindo agora”, palavra atual em destaque, contexto atenuado, auto-scroll e controles maiores.
- O modo Supertonic passa a se chamar **Offline** e continua disponível sem API paga.
- Supertonic offline agora usa 12 etapas por padrão e oferece 8/12/16 etapas.
- Instalação offline refeita: não existe mais download de .tar.bz2 nem etapa pesada de descompactação.
- Os 7 arquivos finais do Supertonic são baixados diretamente do repositório fixado no Hugging Face.
- SHA-256 é calculado durante o próprio download dos arquivos grandes; não há uma segunda leitura pesada na etapa “verificando”.
- Downloads são gravados em staging e só substituem o modelo instalado após todos os arquivos passarem pela validação.
- Frases de leitura foram encurtadas e sentenças longas são quebradas por pontuação para melhorar acompanhamento e cadência.

## 2.0.1

- Corrige o travamento/fechamento no Android durante a instalação da voz neural.
- A verificação SHA-256 e a descompactação BZip2/TAR do modelo passam para isolate de segundo plano.

## 2.0.0

- Reorganização do Auralis como projeto multiplataforma.
- APK Android, instalador Windows e Flatpak Linux via GitHub Actions.
- Supertonic 3 INT8 como TTS neural local.
