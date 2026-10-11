# Evolução do Daily English para estudos e revisão

Análise do checkout em 11/10/2026. Este documento descreve o que existe e o plano proposto; as próximas etapas ainda não foram implementadas.

## Base disponível

- Flutter, Riverpod, GoRouter e SQLite, com separação entre modelos, repositórios, providers e telas.
- Inglês: vocabulário, frases, diário, jogos, registro de estudos e simulados.
- Alterações locais: tela inicial com escolha Inglês/Concursos; tabela `contest_cards` e migração 16 → 17; cadastro de cartões, filtro por matéria e revisão.
- Cartão de concurso com matéria, assunto, pergunta, resposta, observação e fonte. O formulário interpreta texto colado nesses seis campos para conferência antes de salvar.
- Revisão usa `computeSM2`, compartilhado com o restante do app. Há adaptações para a resposta Fácil; não é uma implementação literal do SM-2 clássico.
- Drive faz upload/restauração do arquivo SQLite. Isso é backup, não sincronização de registros nem importação do acervo.
- A função de IA em concursos copia um prompt para uso externo. Não há tutor integrado nesse fluxo.

## Limitações verificadas

1. `_answer` na revisão não bloqueia chamadas concorrentes: toques repetidos durante a gravação podem avançar o índice mais de uma vez e pular cartões. Prioridade alta.
2. O repositório grava somente o estado atual de agendamento. Não preserva cada resposta, avaliação ou tempo gasto; portanto não sustenta métricas históricas por assunto.
3. Cartões sem `next_review_at` entram imediatamente na fila. Não existem os estados de material recebido, estudo concluído e cartão aprovado/ativado.
4. Matéria e assunto são texto em cada cartão, sem entidades próprias. Fonte é texto livre, sem vínculo estruturado com arquivo, versão, página ou trecho.
5. A listagem filtra matéria, mas seus botões Revisar abrem a rota sem esse filtro. A rota e o repositório já aceitam matéria/assunto.
6. Cadastro, carregamento e gravação de revisão precisam de tratamento de erros. A interface não oferece edição de cartões existentes.
7. Sessões atuais representam listening/reading/writing/speaking; precisam de um modelo específico ou uma evolução compatível para estudos de concursos.
8. Não há importador de sessões Markdown, leitor de PDF, notificações diárias, sincronização incremental nem backend Laravel no checkout inspecionado.

## Ordem proposta

### 1. Estabilizar a base

Bloquear respostas concorrentes, tratar erros e permitir tentar novamente; respeitar filtros na revisão; permitir edição de cartões. Atualizar os testes de palavras que estão desatualizados e criar testes de migração 16 → 17, importação dos seis campos e revisão de concursos.

### 2. Entregar o ciclo offline

Introduzir matérias, assuntos, materiais e sessões de estudo, preservando cartões existentes. Importar inicialmente Markdown/texto com prévia e conferência; vincular PDFs como anexos, com leitura como tarefa própria. Não incluir extração automática de PDFs nessa primeira entrega.

Fluxo: importar material → conferir → estudar → concluir → ativar cartões aprovados → responder revisões → consultar histórico.

Separar estado do material (disponível), estado da sessão (pendente/em andamento/concluída) e estado do cartão (rascunho/aprovado/ativo). Apenas importar não ativa revisões. Uma revisão futura é calculada a partir da resposta real; ativar cartão pode disponibilizar sua primeira prática imediatamente.

### 3. Histórico, painel Hoje e lembretes

Registrar cada tentativa e atualizar o agendamento na mesma transação SQLite. Guardar cartão, sessão, instante, avaliação, resposta quando houver e estado anterior/novo do agendamento. Diferenciar autoavaliação de memória de acerto objetivamente corrigido.

Exibir revisões vencidas, materiais pendentes e dificuldades por assunto. Adicionar lembrete local configurável e tratar permissões, fuso horário e retomada do app. Nenhuma dessas funções depende da IA.

### 4. Tutor e backend

Adicionar Laravel para autenticação e chamadas de IA. O app envia o trecho selecionado com sua referência; o tutor explica e propõe cartões em rascunho, sujeitos à aprovação. Guardar referência ao material e ao trecho utilizado; uma referência não garante que o conteúdo esteja correto.

Preparar identificadores estáveis e versões antes de implementar sincronização. Sincronizar respostas como eventos, usar fila de operações offline e marcadores de exclusão; definir explicitamente como resolver edição concorrente de conteúdo e respostas do mesmo cartão em dois aparelhos. Não sobrescrever o banco inteiro para sincronizar.

### 5. Integrações e agentes

Após validar amostras reais, automatizar importação do Drive/Obsidian com identificador de origem e detecção de duplicatas/novas versões. Depois incluir transcrições e MCP. Agentes usam a mesma API e regras de aprovação do app.

## Modelo inicial proposto

- `subjects` e `topics`: organização com IDs, evitando duplicidade por grafia.
- `materials` e referências: origem, conteúdo, versão/hash e anexo local.
- `learning_sessions`: material, estado, início e conclusão reais.
- Cartões existentes: acrescentar vínculos e estado de aprovação/ativação sem apagar os dados atuais.
- `review_events`: registro individual de tentativas e alterações de agendamento.
- Fila de sincronização: introduzir junto do backend, sem bloquear o primeiro ciclo offline.

Na migração, manter os cartões existentes utilizáveis e preservar suas datas de revisão; não tratá-los automaticamente como rascunhos recém-importados.

## Critérios da primeira entrega

- Importar uma sessão real, conferir seus cartões e abrir a fonte vinculada.
- Duplicar uma importação não duplica silenciosamente material/cartões.
- Importação isolada não inicia revisão; conclusão/ativação é explícita.
- Responder offline, fechar/reabrir e preservar histórico e agendamento.
- Toques repetidos não duplicam resposta nem pulam cartão.
- Atualizar uma instalação existente preserva os dados de inglês e concursos.

## Verificação deste checkpoint

- `git diff --check`: sem problemas nas alterações rastreadas.
- `flutter analyze --no-pub`: 1 erro em `test/models/word_test.dart`, que referencia `Word.synonyms` inexistente, e 7 avisos informativos.
- `flutter test --no-pub`: suíte não passou; além do erro de compilação anterior, o banco de teste de palavras não contém `translation_2`, usada pelo modelo atual. Resultado reportado: 19 testes passaram e 11 falhas/erros, incluindo carregamento em cascata.
- Os arquivos do modelo/repositório de palavras e seus testes não têm alterações locais em relação ao HEAD. Esses problemas já estavam no checkout antes do novo módulo.
- Não foi realizada validação visual em Android nem teste de integração da migração de concursos.

## Contexto ainda não confirmado

O agendamento às 15h, o formato real das sessões do vault e a automação Drive/Obsidian foram descritos na conversa, mas não verificados diretamente nesta análise. Antes de implementar a integração, inspecionar uma sessão representativa e a configuração dessa automação.
