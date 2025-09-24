# Audit summary

Summary for [Jenkins instance](http://localhost:8080)

- GitHub Actions Importer version: **1.3.22496 (d3e9bb2592cc709f72b2f6c4a370628d1a1cb5fe)**
- Performed at: **9/24/25 at 18:28**

## Pipelines

Total: **4**

- Successful: **3 (75%)**
- Partially successful: **0 (0%)**
- Unsupported: **1 (25%)**
- Failed: **0 (0%)**

### Job types

Supported: **3 (75%)**

- org.jenkinsci.plugins.workflow.multibranch.WorkflowMultiBranchProject: **2**
- flow-definition: **1**

Unsupported: **1 (25%)**

- scripted: **1**

### Build steps

Total: **40**

Known: **39 (97%)**

- echo: **21**
- sh: **10**
- unstash: **2**
- archiveArtifacts: **2**
- stash: **1**
- cleanWs: **1**
- junit: **1**
- checkout: **1**

Unsupported: **1 (2%)**

- script: **1**

Actions: **56**

- run: **33**
- actions/checkout@v4.1.0: **17**
- actions/upload-artifact@v4.1.0: **3**
- actions/download-artifact@v4.1.0: **2**
- EnricoMi/publish-unit-test-result-action@v2.12.0: **1**

### Triggers

Total: **2**

Known: **2 (100%)**

- hudson.model.ParametersDefinitionProperty: **2**

Actions: **5**

- workflow_dispatch: **5**

### Environment

Total: **2**

Known: **2 (100%)**

- BUILD_DIR: **1**
- APP_NAME: **1**

Actions: **2**

- BUILD_DIR: **1**
- APP_NAME: **1**

### Other

Total: **3**

Unknown: **2 (66%)**

- buildDiscarder: **1**
- timestamps: **1**

Unsupported: **1 (33%)**

- timeout: **1**

### Manual tasks

Total: **13**

Self hosted runners: **13**

- `docker-agent`: **13**

### Successful

#### declarative-example

- [declarative-example/main/.github/workflows/main.yml](declarative-example/main/.github/workflows/main.yml)
- [declarative-example/config.json](declarative-example/config.json)
- [declarative-example/main/config.json](declarative-example/main/config.json)

#### declarative-example-advanced

- [declarative-example-advanced/main/.github/workflows/main.yml](declarative-example-advanced/main/.github/workflows/main.yml)
- [declarative-example-advanced/config.json](declarative-example-advanced/config.json)
- [declarative-example-advanced/main/config.json](declarative-example-advanced/main/config.json)

#### Groovy_Advanced

- [Groovy_Advanced/.github/workflows/groovy_advanced.yml](Groovy_Advanced/.github/workflows/groovy_advanced.yml)
- [Groovy_Advanced/config.json](Groovy_Advanced/config.json)
- [Groovy_Advanced/jenkinsfile](Groovy_Advanced/jenkinsfile)

### Unsupported

#### groovy-example

- [groovy-example/error.txt](groovy-example/error.txt)
- [groovy-example/config.json](groovy-example/config.json)

### Failed

#### groovy-example

- [groovy-example/error.txt](groovy-example/error.txt)
- [groovy-example/config.json](groovy-example/config.json)
