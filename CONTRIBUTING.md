# Contributing

First off, thank you so much for considering a contribution to this project. We welcome contributions from everyone!

<br/>

## Table of Contents

-   [1. How can I contribute?](#1-how-can-i-contribute)
-   [2. Guidelines](#2-guidelines)
    -   [2.1 Git commit messages](#21-git-commit-messages)
    -   [2.2 Coding style guide](#22-coding-style-guide)
-   [3. Code Review Process](#3-code-review-process)
-   [4. Community and Communication](#4-community-and-communication)

<br/>

[//]: # '## 1. How can I contribute?'

## How to Contribute?

Contributing is simple. Here's how you can do it:

1. **Identify an Issue**: Look for existing [Issues](https://github.com/stoicswe/Endfield_FineWine/issues) or create your own explaining the feature or fix.
2. **Fork the Repository**: Click on the fork button in the top right corner.
3. **Clone the Repository**: After forking, clone the repo to your local machine to make changes.
4. **Set up Your Environment**: Set up the repository by following the Quick Start section of the [README.md](README.md).
5. **Create a New Branch**: Before making any changes, switch to a new branch:
    ```bash
    # For bugs:
    git checkout -b bug/your-new-branch-name
    
    # For features:
    git checkout -b feature/your-new-branch-name
    ```
6. **Make Changes**: Implement your feature or fix.
7. **Run Tests**: Ensure your changes do not break any existing functionality.
8. **Write Commit Messages**: Please try to make your commit messages adequately descriptive.
9. **Push to GitHub**: After committing your changes, push them to GitHub:
    ```
    git push origin your-new-branch-name
    ```
10. **Submit a Pull Request**: Go to your repository on GitHub and click the 'Compare & pull request' button. Fill in the details and submit.

<br/>

[//]: # '## 2. Guidelines'

## Guidelines

[//]: # '### 2.1 Git commit messages'

### Commit Messages

While we do not have a distinct commit message style, it is best to ensure that your commit message contains enough description as to what the goal of the commit is.

[//]: # '### 2.2 Coding style guide'

### Coding Style Guide

We follow the standard practice for C++ coding styles.

```cpp
namespace MyNameSpace {
  class MyClass {
  
  public:
    void myFunction() {
      // Do something
    }
  }
}
```

<br/>

[//]: # '## 3. Code Review Process'

### Code Review

All submissions, including submissions by project maintainers, require review. We use GitHub pull requests for this process. If your pull request is particularly urgent, please mention this in the request.

<br/>

[//]: # '## 4. Community and Communication'

### Community and Communication

Follow discussions in the [GitHub Issues](https://github.com/{username}/{repo}/issues) section of our repository.
