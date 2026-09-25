
with open('.agents/rules/forecasting.md', 'a', encoding='utf-8') as f:
    f.write('''
## Advanced Demand Forecasting & Time Series Analysis (Grounded in Empirical Research)
Based on a synthesis of 49 technical sources and empirical competitions (like M4/M5), the following principles and methodologies should guide forecasting implementations:

### 1. Global Cross-Learning & Machine Learning
- **LightGBM Dominance:** In large retail hierarchies, global ML models (specifically LightGBM) pooling information across all SKUs massively outperform local series-by-series models. LightGBM excels due to its fast computation and handling of mixed tabular features (calendar events, prices, etc.).
- **Zero-Inflated Counts:** For SKU-store level zero-inflated and right-skewed sales data, top solutions maximize the negative log-likelihood of the **Tweedie distribution** (or Poisson regression).
- **Intermittent Tails:** For highly disaggregated, sparse inventory tails, classic intermittent methods (Croston, SBA, TSB) remain highly competitive.

### 2. Deep Probabilistic Neural Architectures
- Use calibrated uncertainty intervals for safety stock optimization and risk management using probabilistic neural networks.
- **DeepAR:** Autoregressive RNN/LSTM that learns global models from related series, using Negative Binomial likelihoods for count data natively.
- **Temporal Fusion Transformer (TFT):** Attention-based architecture designed for multi-horizon forecasting, combining Gated Residual Networks and Variable Selection Networks to output direct quantile forecasts minimizing pinball loss.
- **N-BEATS & N-HiTS:** Fully connected architectures based on doubly residual stacking and multi-rate input sampling. N-BEATS decomposes signals into trend and seasonality, while N-HiTS improves long-horizon accuracy over sparse Transformers.

### 3. Zero-Shot Time Series Foundation Models (LTMs)
For rapid baseline generation without task-specific retraining, utilize foundation models:
- **Chronos (AWS):** Adapts T5 language model by scaling/quantizing real-valued time series into discrete tokens.
- **MOIRAI (Salesforce):** Masked encoder transformer pre-trained on LOTSA (27B observations) handling arbitrary multivariate dimensions via Any-variate Attention.
- **TimesFM (Google):** 200M parameter decoder-only transformer pre-trained on >100B timepoints, using input/output patching for fast long-horizon inference.
- **Lag-Llama (Morgan Stanley / Mila):** General-purpose foundation model based on LLaMA architecture utilizing lags as covariates.

### 4. Hierarchical Forecast Reconciliation (MinT Framework)
- Independent base forecasts across product/geographical hierarchies are incoherent.
- **MinT-Shrink (Minimum Trace):** The optimal reconciliation standard for large retail hierarchies where the number of series exceeds sample size. It shrinks off-diagonal sample covariance elements toward a diagonal target, ensuring mathematically coherent forecasts across supply chain levels (SKU -> Store -> Region -> National).

### 5. Fast & Frugal Retail Forecasting & Process Governance
- **Occam's Razor:** Complex models can overfit historical noise and incur massive computational costs and carbon emissions. Identifying reduced pools of simple statistical models maintains accuracy while saving cloud computing costs.
- **Forecast Value Added (FVA):** Implement FVA governance frameworks to measure the change in forecast accuracy attributable to each S&OP step. 52% of manual executive overrides degrade accuracy (negative FVA). FVA stairstep reporting identifies this waste, enabling organizations to trust automated statistical baselines and require justification for manual overrides.
''')

