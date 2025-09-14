# Development Guidelines for Claude

## Rails Philosophy
- Always follow Rails conventions and idioms
- Use Rails built-in APIs and tools before creating custom solutions
- Keep rails up to date
- Don't reinvent the wheel - Rails likely already has what you need
- Prefer Rails generators, helpers, and established patterns
- Before creating your own solutions check and see (with a web search if necessary) to see if any current and well maintained rubygems exist that might fulfill the feature request
- Try and be consitant.  Follow the code base approach to e.g. services, adapters, restful controllers (instead of custom actions), anything where a precedent exits.

## General Principles
- Convention over configuration
- Don't repeat yourself (DRY)
- Follow existing codebase patterns
- Use Rails idioms and established practices