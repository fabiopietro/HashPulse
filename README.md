# HashPulse

**Data Vitality & Integrity Monitor for SQL**

---

### 🧭 Overview

HashPulse is a lightweight, high-precision SQL auditing framework designed to measure the *vitality* of data. It doesn’t just compare records — it evaluates their **entropy**, detects **duplications**, and quantifies the **integrity score** of entire datasets, allowing engineers to anticipate silent drifts and data degradation before they reach production.

Think of it as a *pulse check* for your tables: a living monitor that reads the heartbeat of your data through cryptographic hashing and statistical entropy.

---

### ⚙️ Features

* **Full Table Auditing:** Compare homologation vs. production tables using hash-based deltas.
* **Entropy Analysis:** Measure data variability to detect duplication or stagnation.
* **Duplicate Detection:** Identify redundant rows by both key and content hash.
* **Structural Comparison:** Validate that both tables have identical schemas.
* **Reliability Score:** Quantify overall table health via weighted severity levels.
* **JSON Export:** Generate structured audit outputs for downstream analytics.
* **Verbose Diagnostics:** Optional debug mode for query tracing.

---

### 🧩 Core Metrics

| Metric                | Description                                                                               |
| --------------------- | ----------------------------------------------------------------------------------------- |
| **Entropy**           | Measures uniqueness density across hashes. Low entropy suggests duplicated or stale data. |
| **Reliability Score** | Weighted index (0–1) based on delta types and severities.                                 |
| **Delta Analysis**    | Distinguishes between new, deleted, and divergent records.                                |
| **Duplicate Hashes**  | Detects redundant content across unique keys.                                             |
| **Execution Time**    | Runtime diagnostics for performance tracking.                                             |

---

### 🧠 Entropy Levels

| Range         | Health State | Interpretation                                              |
| ------------- | ------------ | ----------------------------------------------------------- |
| `< 0.01`      | 🚨 Critical  | Mass replication — potential ingestion loop or corrupt ETL. |
| `0.01 – 0.10` | ⚠️ Low       | Structural duplication; staging layer not deduplicated.     |
| `0.10 – 0.50` | ⚙️ Moderate  | Expected repetition in categorical or lookup data.          |
| `> 0.50`      | ✅ High       | Healthy distribution, strong data vitality.                 |

---

### ⚡ Quick Start

#### **1️⃣ Clone the repository**

```bash
git clone https://github.com/fabiopietro/HashPulse.git
cd HashPulse
```

#### **2️⃣ Open in SQL Server Management Studio (SSMS)**

Import the main script (`HashPulse_Audit.sql`) and review the parameters at the top of the file:

```sql
DECLARE @TabelaProducao SYSNAME = N'tbProducao';
DECLARE @TabelaHomologacao SYSNAME = N'tbHomologacao';
DECLARE @ColunasChave NVARCHAR(MAX) = N'codigo_simulacao,modelo_agrup';
DECLARE @ColunasExcecao NVARCHAR(MAX) = N'data_parametro,expansao';
```

#### **3️⃣ Execute under controlled environment**

Run in a sandbox or development database first — the procedure does **not** modify data, only reads and aggregates.

#### **4️⃣ Interpret the output**

Look for the entropy percentage, delta counts, and reliability score. The higher the entropy and reliability, the healthier your dataset.

Example summary:

```
Entropia: 82.3%
Diagnóstico: Muito alta — Tabela saudável.
Confiabilidade: 99.94%
✅ Integridade dentro da faixa esperada.
```

#### **5️⃣ Optional JSON Export**

Enable the JSON export flag to create a portable audit summary for visualization:

```sql
SET @jsonAuditoria = 1;
```

Output example:

```json
{
  "TabelaProducao": "tbProducao",
  "TabelaHomologacao": "tbHomologacao",
  "DataExecucao": "2025-11-08T10:12:54Z",
  "AuditoriaDeltas": [
    {"Chave": "1234|A1", "TipoDelta": "HASH", "Mensagem": "Diferença imprevista"},
    {"Chave": "1288|A3", "TipoDelta": "NEW", "Mensagem": "Registro novo"}
  ]
}
```

---

### 🧮 Example Output

```
📊 AUDITORIA DE TABELAS – RELATÓRIO EXECUTIVO
Data de Execução: 2025-11-08 10:12:54
Tabela Produção : [tbProducao]
Tabela Homolog. : [tbHomologacao]

Resumo de Deltas
Registros novos:      145
Registros excluídos:   98
Hash divergente:       21
Chaves duplicadas:     0
Hashes duplicados:     4

Entropia:              82.3%
Diagnóstico:           Muito alta — Tabela saudável.
Confiabilidade:        99.94%
✅ Integridade dentro da faixa esperada.
Tempo de execução:     1.23 s
```

---

### 🚀 Roadmap

* [ ] Version for single-table entropy profiling.
* [ ] Integration with Power BI or Grafana dashboards.
* [ ] Stored procedure packaging and deployment template.
* [ ] Optional Python wrapper for automated scheduling.

---

### 📦 Installation

Simply copy the SQL script into your environment and execute under controlled permissions (recommended: sandbox or dev database). No external dependencies required.

---

### 🧾 License

MIT License © 2025 [Fábio Pietro Paulo](https://github.com/fabiopietro)

---

### 💬 Hook

> “Data integrity isn’t only about comparison — it’s about vitality.
> Entropy is the silent heartbeat of a healthy dataset.”

---

### 🔖 Hashtags

#DataObservability #DataQuality #SQLServer #DataEngineering #Analytics #DataGovernance #DataAudit #SQLTips #DataIntegrity #ETL #PowerBI #BusinessIntelligence #DataHealth #EntropyAnalysis #DataReliability #DataMaturity #DataDriven
