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

## Code Quality
- Follow Sandi Metz rules within reason (rails libs and apis will sometimes violate)
- Also SOLID within reason (as above)
- Jobs should do one thing, keep logic in the classes they call
- Consider when designing complex services e.g. piplines, or operatinos that they should be debugable.  What I mean is one should be able to test business logic or run it via the rails console for example. Passing data to a service should be straightforward.
- Let's avoid callbacks that cause cascading or hard to control side effects
- no habtm
- always try to validate data before persisting
- keep designs consistent e.g. adapters, services etc.
- avoid n+1s

## Writing code
Use a run, test, refactor loop i.e. 
- get it working
- passing test
- refactor (rules above and lint using rails best practices or https://github.com/standardrb/standard-rails)
Repeat until code is clean, performant and maintainable
- use modern syntax e.g. no begin blocks


