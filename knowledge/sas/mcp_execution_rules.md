# SAS Core Knowledge & Standards

This directory contains the normalized SAS skill set extracted from various collections, categorized into domains such as administration, data management, forecasting, machine learning, text analytics, etc.

## SAS Coding Best Practices & Performance Guide

This section serves as a deep dive into SAS coding best practices, focusing on maintainability, performance optimization, and modern SAS architectural paradigms (such as SAS Viya and CAS). 

### 1. General Coding Standards & Maintainability
Writing maintainable SAS code is critical for enterprise environments where code lifecycles span years.
* **Explicit System Options:** Always set appropriate system options at the beginning of your script. Use `OPTIONS MSGLEVEL=I;` to print informational messages about index usage, merge processing, and missing values.
* **Header Documentation:** Every program, macro, and complex data step should have a header block detailing the author, date, purpose, inputs, and outputs.
* **Naming Conventions:** Use descriptive names for datasets and variables (e.g., `cust_trans_2023` rather than `ct23`).
* **Code Formatting:** Indent code blocks consistently (e.g., 4 spaces). Standardize capitalization (e.g., UPPERCASE for SAS keywords, lowercase for variables).
* **Libname Management:** Clear out temporary datasets or WORK library files at the end of large processes using `PROC DATASETS LIB=WORK KILL Nolist; QUIT;` to free up system storage.

### 2. The DATA Step: Core Engine Optimization
The DATA step is the workhorse of traditional SAS processing. Optimizing it yields the most significant performance gains in SAS 9.4 environments.
* **Filtering and Subsetting Early:** Always use `WHERE` instead of `IF` when reading from an existing dataset.
* **Advanced Lookups:** For looking up values from a smaller table against a massive table, use Hash Objects instead of sorting and merging.
* **Execution Efficiency:** Use Arrays to perform repetitive operations. Declare character variable lengths explicitly using the `LENGTH` statement.

### 3. SAS Macro Language: Dynamic but Dangerous
Macro code writes SAS code. It should be used to automate repetitive tasks, not to perform data manipulation.
* **Limit Macro Overuse:** Do not use macro logic (`%IF / %THEN`) to evaluate dataset values.
* **Scope Management:** Explicitly declare macro variables as `%LOCAL` or `%GLOBAL`.
* **SYMPUTX vs SYMPUT:** Always use `CALL SYMPUTX()` over `CALL SYMPUT()`.
* **Using %SYSFUNC:** Use `%SYSFUNC()` to execute base SAS functions within macro code.

### 4. PROC SQL vs PROC FedSQL
`PROC SQL` provides a powerful alternative to the DATA step for joins and complex queries. 
`PROC FedSQL` is SAS's implementation of ANSI SQL:1999 standard, designed to operate seamlessly in cloud/distributed environments (CAS).
* **FedSQL in CAS:** In SAS Viya, `PROC FedSQL` processes queries in parallel across multiple nodes and threads, whereas `PROC SQL` operates as a single-threaded operation. Always use FedSQL in CAS for joining tables.

### 5. CAS Programming: The SAS Viya Era
Cloud Analytic Services (CAS) is the distributed, in-memory computing engine for SAS Viya. Coding for CAS requires a paradigm shift.
* **Multithreaded Execution:** When a DATA step runs in CAS, it runs in parallel across all worker nodes. This means data order is not guaranteed.
* **Retain and Lag:** Because data is chunked and processed on different threads, functions like `LAG()` and statements like `RETAIN` will only operate within the specific thread/chunk. Use a `BY` statement for sequential processing.
* **CAS Actions:** CAS actions are the atomic operations of the CAS engine. Wrapping CAS actions in `PROC CAS` or Python/R is often much more performant than legacy PROCs.

### 6. Resource Management & Performance Tuning
* **Dataset Compression:** Always compress large datasets to save disk space and I/O wait times.
* **Turn off ODS:** When running pure ETL or data manipulation jobs, suppress ODS output to save CPU time.
