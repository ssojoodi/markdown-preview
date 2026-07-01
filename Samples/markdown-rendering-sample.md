# Markdown Rendering Sample

This file is intended for testing Markdown Preview rendering. It includes regular prose, **bold text**, *italic text*, ***bold italic text***, `inline code`, and a [link to the project README](../README.md).

## Bullets

* First level item with **bold emphasis**
  * Second level item with *italic emphasis*
  * Second level item with `inline code`
    * Third level item with a [relative link](../LICENSE)
* First level item 2
  * Second level item 2
  * Second level item 3

## Numbered List

1. Open a Markdown file.
2. Switch into edit mode.
3. Save the changes.
4. Return to preview mode.

## Table

| Feature | Expected Rendering | Status |
| --- | --- | ---: |
| Bullets | Nested indentation is preserved | 1 |
| Formatting | Bold, italic, and code render inline | 2 |
| Links | Relative and external links are clickable | 3 |
| Mermaid | Diagrams render visually, not as source text | 4 |

## Mermaid ERD

```mermaid
erDiagram
    CUSTOMER ||--o{ ORDER : places
    ORDER ||--|{ LINE_ITEM : contains
    PRODUCT ||--o{ LINE_ITEM : appears_in

    CUSTOMER {
        int id
        string name
        string email
    }

    ORDER {
        int id
        date ordered_at
        string status
    }

    LINE_ITEM {
        int id
        int quantity
        decimal unit_price
    }

    PRODUCT {
        int id
        string sku
        string name
    }
```

## Mermaid Sequence Diagram

```mermaid
sequenceDiagram
    participant User
    participant App as Markdown Preview App
    participant Renderer as Markdown Renderer
    participant WebView

    User->>App: Open Markdown file
    App->>Renderer: Render Markdown text
    Renderer-->>App: Return HTML
    App->>WebView: Load rendered HTML
    WebView-->>User: Show preview

    User->>App: Switch to edit mode
    User->>App: Save changes
    App->>Renderer: Re-render updated Markdown
    App->>WebView: Refresh preview
```
