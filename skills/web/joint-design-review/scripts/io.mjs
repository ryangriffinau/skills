/**
 * Output channels shared by the joint-design-review scripts.
 *
 * Every script here is a CLI with two channels that must not blur together:
 * stdout carries the machine-readable result a caller pipes or parses, stderr
 * carries progress and diagnostics for the human watching. Writing to the
 * streams directly — rather than through console, which is a debugging
 * affordance — keeps that split explicit at every call site.
 */

/** Machine channel: the result. Anything a caller may pipe or parse. */
export const out = (line = "") => process.stdout.write(`${line}\n`);

/** Human channel: progress, warnings, refusals. Never part of the result. */
export const note = (line = "") => process.stderr.write(`${line}\n`);
