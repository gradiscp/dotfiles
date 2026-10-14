# Use subagents sparingly

Applies to every task, in every project.

- Small and medium changes Claude does itself in the main conversation: one area, a few files,
  also the UI rework of a single page. A subagent alone needs 5-10 minutes to read itself in.
- Subagents only when several independent, large parts can run in parallel (each more than
  about 30 minutes), or for broad searches and reviews across many files.
- Before starting any: say which agents, what for, and the estimated duration.
- New small requests while an agent is running: do them yourself, don't queue them to the agent.
