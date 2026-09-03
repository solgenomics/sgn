# Optimization Plan: Genotype Download Performance

**Overall status (as of 2026-07-31): Phases 1 and 2 are implemented and merged to `topic/genotype_download_optimization`** (commits `53bb6a8446`, `c12330bedf`, `b30459f2a6`). Remaining work: validate performance/memory numbers and run the correctness tests below, then decide on Phase 3. Phase 4 remains optional/deferred.

**Post-Phase-2 regression found and fixed (2026-07-31):** the initial Phase 2 implementation (`b30459f2a6`) had `init_genotype_iterator()` eagerly call `_bulk_fetch_genotypeprop_data()` for every genotype_id in the whole search result, storing it all in `_bulk_genotypeprop_data` for the life of the iterator. This defeated the iterator's memory-bounding design (its own POD says "Iterative search retrieval minimizes memory usage") and caused the worker process to be OOM-killed (`signal 9`) on large downloads via `download_gbs_action`, surfacing to users as an abrupt 404. Fixed by moving the bulk fetch into `get_next_genotype_info()`, windowed at a time — the query-count win from Phase 2 is unchanged, but peak memory is now bounded to one window instead of the whole result set. `init_genotype_iterator()` and `get_next_genotype_info()` in [lib/CXGN/Genotype/Search.pm](lib/CXGN/Genotype/Search.pm) were updated accordingly.

**Follow-up (still 2026-07-31):** after the windowing fix above, the download still got SIGKILL'd. Root cause: a fixed `_bulk_fetch_batch_size` of 200 genotypes bounds *query count* but not *memory* — a genotype's jsonb blob can unpack to tens of thousands of `jsonb_each` rows, so a 200-genotype window against a 50k-100k-marker protocol still materializes 10-20 million Perl hash entries at once. Added `_bulk_fetch_window_size()` (`Search.pm:797-807`) and a new `_bulk_fetch_max_result_rows` attribute (default 1,000,000, `Search.pm`) so the actual genotypes-per-window count is `min(_bulk_fetch_batch_size, _bulk_fetch_max_result_rows / markers_per_genotype)` — i.e. the window shrinks automatically as marker count grows, keeping total row count (the real memory driver) bounded rather than genotype count alone. `_bulk_fetch_max_result_rows` is tunable if OOMs persist on a given VM.

## Context

Large genotyping protocol downloads in BreedBase are currently very slow. For datasets with 1000+ accessions and 50,000+ markers, downloads can take 2-3 minutes or longer. The bottleneck is in the `CXGN::Genotype::Search` module's VCF generation workflow.

**Current Process:**
1. Query database for stock/genotype metadata
2. Loop through each accession serially
3. For each accession, execute nested queries to fetch marker data (N+1 query pattern)
4. Write data to temp file in marker-major format
5. Submit SLURM job to transpose the file
6. Return file handle

**Problem:** The nested N+1 query pattern results in thousands of database round trips. For 1000 genotypes, this can be 2,000-4,000+ individual queries, causing significant latency.

## Investigation Summary

Three critical bottlenecks were identified:

### 1. Nested N+1 Query Loop (CRITICAL)
**Location:** [Search.pm:700-710](lib/CXGN/Genotype/Search.pm#L700-L710), [Search.pm:1184-1193](lib/CXGN/Genotype/Search.pm#L1184-L1193)

The code executes:
- 1 query per genotype to get genotypeprop IDs
- 1 query per genotypeprop ID to fetch marker data via JSONB

This results in O(G×GP) queries where G = genotypes, GP = genotypeprop records per genotype.

**Impact:** For 1000 genotypes: ~2,000-4,000 queries taking 30-60 seconds

### 2. Stock Synonym Queries (MAJOR)
**Location:** [Search.pm:565](lib/CXGN/Genotype/Search.pm#L565), [Search.pm:1009](lib/CXGN/Genotype/Search.pm#L1009)

Each accession instantiates a `CXGN::Stock::Accession` object which triggers a lazy-loaded DBIx::Class query for synonyms via `_retrieve_stockprop()`.

**Impact:** For 1000 genotypes: ~1,000 additional queries taking 10-20 seconds

### 3. Protocol Metadata Multi-Query (MODERATE)
**Location:** [Search.pm:1044-1076](lib/CXGN/Genotype/Search.pm#L1044-L1076)

Four separate queries per protocol to fetch marker metadata.

**Impact:** Usually small (few protocols), but 4-12 unnecessary round trips

## Optimization Strategy

### Phase 1: Foundation & Quick Wins (Estimated: 1-2 days)

**Priority: HIGH**

#### 1.1 Verify Database Indexes
Ensure optimal indexes exist on the `genotypeprop` table:

```sql
-- Composite index for genotype lookups
CREATE INDEX IF NOT EXISTS idx_genotypeprop_genotype_type 
    ON genotypeprop(genotype_id, type_id);

-- GIN index for JSONB marker data queries
CREATE INDEX IF NOT EXISTS idx_genotypeprop_value_gin 
    ON genotypeprop USING GIN (value);

-- Optimized GIN index for JSONB path operations
CREATE INDEX IF NOT EXISTS idx_genotypeprop_value_keys
    ON genotypeprop USING GIN (value jsonb_path_ops);
```

**Files to modify:**
- Create new migration in `db/` directory
- Verify indexes don't already exist with `\d genotypeprop`

**Expected impact:** 2-5x speedup on JSONB queries, critical prerequisite for bulk query optimization

#### 1.2 Bulk Synonym Pre-fetching
Replace per-accession `Stock::Accession` instantiation with bulk synonym fetch.

**Current pattern (line 1009):**
```perl
my $stock_object = CXGN::Stock::Accession->new({schema=>$self->bcs_schema, stock_id=>$stock_obj_id});
# ... later ...
synonyms => $stock_object->synonyms,  # Triggers individual query
```

**Optimized pattern:**
```perl
# After collecting all stock_ids in init_genotype_iterator():
my @unique_stock_ids = keys %seen_stock_ids;
my $stocklookup = CXGN::Stock::StockLookup->new({schema => $self->bcs_schema});
my $synonym_hash = $stocklookup->get_stock_synonyms('stock_id', 'accession', \@unique_stock_ids);
$self->_bulk_synonym_data($synonym_hash);

# In loop, retrieve from hash:
synonyms => $self->_bulk_synonym_data->{$stock_obj_id} || [],
```

**Files to modify:**
- [lib/CXGN/Genotype/Search.pm](lib/CXGN/Genotype/Search.pm)
  - Add attribute: `_bulk_synonym_data => (isa => 'HashRef', is => 'rw')`
  - Modify `init_genotype_iterator()` after line 1032 to bulk fetch synonyms
  - Replace line 1009 Stock::Accession instantiation with hash lookup
  - Use same hash in `get_cached_file_VCF()` around line 1910

**Expected impact:** 1,000x reduction in synonym queries (1000 queries → 1 query), saving 10-20 seconds

### Phase 2: Critical Database Query Optimization (Estimated: 1-2 days)

**Priority: CRITICAL**
**Status: Complete (commit `b30459f2a6`, 2026-07-31). Plan revised below after tracing the actual code (2026-07-27) — the real fix is simpler than originally scoped, and was implemented as described.**

#### 2.1 Bulk query, modifying `init_genotype_iterator()` / `get_next_genotype_info()` in place

**Investigation findings that changed the approach:**

- The nested loop is at [Search.pm:1236-1245](lib/CXGN/Genotype/Search.pm#L1236-L1245) (current line numbers, shifted from the original 1184-1193 by the Phase 1 commits), inside `get_next_genotype_info()`:
  ```perl
  $h_genotypeprop->execute($genotype_id);
  while (my ($genotypeprop_id) = $h_genotypeprop->fetchrow_array) {
      $genotypeprop_h->execute($genotypeprop_id);
      while (my ($marker_name, @genotypeprop_info_return) = $genotypeprop_h->fetchrow_array()) {
          for my $s (0 .. scalar(@$genotypeprop_hash_select_arr)-1){
              $genotypeprop_info{selected_genotype_hash}->{$marker_name}->{$genotypeprop_hash_select->[$s]} = $genotypeprop_info_return[$s];
          }
      }
  }
  ```
  `$h_genotypeprop` is `_iterator_genotypeprop_query_handle`, prepared in `init_genotype_iterator()` as (`Search.pm:1154-1157`):
  ```sql
  SELECT genotypeprop_id FROM genotypeprop WHERE genotype_id = ? AND type_id = ?
  ```
  `$genotypeprop_h` is `_genotypeprop_h`, prepared at `Search.pm:1148-1152`:
  ```sql
  SELECT s.key, s.value->>'GT', s.value->>'DS', ...   -- one column per genotypeprop_hash_select field
  FROM genotypeprop, jsonb_each(genotypeprop.value) as s
  WHERE genotypeprop_id = ? AND s.key != 'CHROM' AND type_id = ? [AND s.key IN (...filtered markers...)]
  ```
- **Key discovery:** `genotypeprop` already has a direct `genotype_id` column (used by the first query above), so the `genotypeprop_id` indirection is unnecessary — both queries filter on `type_id` and resolve to the same row(s). There is no need for a LATERAL join or `jsonb_object_agg`; we can query directly against `genotype_id` instead of `genotypeprop_id`, and do it once for a whole batch of genotype IDs instead of once per genotype.
- The `(genotype_id, type_id)` composite index needed for this already exists (`idx_genotypeprop_genotype_type`, added in `db/00207/AddGenotypepropIndexes.pm`, commit `53bb6a8446`), so no further migration is required for Phase 2.
- Per user decision (2026-07-27): modify the existing methods **in place** rather than adding parallel `_optimized` methods. The output shape is unchanged — only *when* the marker data is fetched changes (upfront in bulk vs. lazily per row) — and [t/unit_fixture/CXGN/Genotype/Search.t](t/unit_fixture/CXGN/Genotype/Search.t) already does full `is_deeply()` structural comparisons of `get_next_genotype_info()` output, so it is a strong regression guard. This avoids duplicating `init_genotype_iterator()` (~380 lines), `get_next_genotype_info()` (~80 lines), and `get_cached_file_VCF()` (~300 lines), and needs no caller/controller changes.

**Optimized query (replaces both queries above, run once per batch of genotype_ids):**
```sql
SELECT genotypeprop.genotype_id, s.key, s.value->>'GT', s.value->>'DS', ...
FROM genotypeprop, jsonb_each(genotypeprop.value) as s
WHERE genotypeprop.genotype_id IN (?, ?, ..., ?)   -- batch of genotype_ids
  AND s.key != 'CHROM'
  AND type_id = ?
  [AND s.key IN (...filtered markers...)]           -- same filtered-markers logic as today
```
This reuses the exact same select-list construction (`$genotypeprop_hash_select_sql`) and filtered-markers clause (`$filtered_markers_sql`) already built in `init_genotype_iterator()` at `Search.pm:1135-1146` — only the `WHERE` target column changes from `genotypeprop_id = ?` to `genotypeprop.genotype_id IN (...)`, and it's parameterized over a batch of IDs instead of one ID per call. Genotype IDs come from the earlier DB query result (all integers), so building the `IN (...)` list via `join(',', @batch)` is safe and consistent with the existing style used elsewhere in this file (e.g. `$accession_sql`, `$trial_sql`).

**Implementation steps:**

1. **Add new attribute** next to the existing `_bulk_synonym_data` (`Search.pm:303-307`):
   ```perl
   has '_bulk_genotypeprop_data' => (
       isa => 'HashRef',
       is => 'rw',
       default => sub {{}}
   );

   has '_bulk_fetch_batch_size' => (
       isa => 'Int',
       is => 'rw',
       default => 200,  # each genotype can unpack to tens of thousands of jsonb_each rows; keep batches modest
   );
   ```

2. **Add `_bulk_fetch_genotypeprop_data()` private method** (new sub, placed after `init_genotype_iterator()`):
   - Args: `$genotype_ids` (ArrayRef of all genotype_ids collected in `@genotypeprop_infos`), plus closes over `$vcf_genotyping_cvterm_id`, `$genotypeprop_hash_select_sql`, `$genotypeprop_hash_select` (or receives them as args).
   - Loops over `$genotype_ids` in chunks of `_bulk_fetch_batch_size`, building `genotype_id IN (...)` per chunk (same `$filtered_markers_sql` clause reused unchanged).
   - For each returned row `($genotype_id, $marker_name, @field_values)`, fills `$result{$genotype_id}{$marker_name}{$field} = $value` for each field in `$genotypeprop_hash_select`.
   - Returns a HashRef keyed by `genotype_id`, each value shaped exactly like the old per-row `selected_genotype_hash` (`{marker_name}{field} => value`).

3. **Modify `init_genotype_iterator()`** (`Search.pm:1134-1157`):
   - Remove construction of `$genotypeprop_q` / `$genotypeprop_h` / `_genotypeprop_h`, and the `$q2` / `$h2` / `_iterator_genotypeprop_query_handle` prepared statement (no longer needed — replaced by the bulk fetch).
   - After `%filtered_markers` is finalized (line 1132) and `@genotypeprop_hash_select_arr` is built (line 1139-1140), collect `my @genotype_ids = map { $_->{markerProfileDbId} } @genotypeprop_infos;` and call `$self->_bulk_fetch_genotypeprop_data(\@genotype_ids, $vcf_genotyping_cvterm_id, $genotypeprop_hash_select_sql, $genotypeprop_hash_select, \%filtered_markers)`, storing the result via `$self->_bulk_genotypeprop_data(...)`.

4. **Modify `get_next_genotype_info()`** (`Search.pm:1236-1245`):
   - Remove the `$h_genotypeprop` / `$genotypeprop_h` variable lookups (`_iterator_genotypeprop_query_handle`, `_genotypeprop_h`, now unused) and the nested `execute`/`fetchrow_array` loop.
   - Replace with:
     ```perl
     $genotypeprop_info{selected_genotype_hash} = $self->_bulk_genotypeprop_data->{$genotype_id} || {};
     ```

5. **Remove now-unused attributes**: `_iterator_genotypeprop_query_handle` (`Search.pm:197-200`) and `_genotypeprop_h` (`Search.pm:278-281`), since nothing constructs or reads them anymore.

**Expected impact:** ~2,000-4,000 queries → ~1-25 queries (batch of 200 genotypes ≈ `ceil(G/200)` queries), saving 30-60 seconds for 1000-genotype downloads.

**Risk mitigation:**
- Batch size of 200 is a starting point — each genotype's jsonb blob can unpack to tens of thousands of `jsonb_each` rows, so a batch's result set is roughly `batch_size × markers_per_genotype` rows. Tune `_bulk_fetch_batch_size` down further if memory pressure shows up during Phase 2 testing (see Testing & Validation below), and consider making it a constructor argument if different callers need different tuning.
- No fallback path is being kept (per the in-place decision above) — the existing `Search.t` test and a manual before/after `EXPLAIN ANALYZE` + byte-for-byte VCF comparison (see below) are the safety net instead of a parallel implementation.

**Correction (2026-07-31):** the risk mitigation above assumed batching only needed to bound *query* size, but the initial implementation (step 3 above) called `_bulk_fetch_genotypeprop_data()` once in `init_genotype_iterator()` with **every** genotype_id from the whole search, so `_bulk_genotypeprop_data` held the entire dataset's marker data in memory for the life of the iterator regardless of batch size — reintroducing an unbounded-memory problem (this time in Perl heap instead of DB round trips) and causing OOM kills (`signal 9`) on large `download_gbs_action` requests. Fixed by moving the `_bulk_fetch_genotypeprop_data()` call from `init_genotype_iterator()` into `get_next_genotype_info()`, invoked only when crossing into a new window, fetching just that window's genotypes' worth of data and replacing (not accumulating onto) `_bulk_genotypeprop_data` each time.

**Correction #2 (still 2026-07-31):** even windowed, a *fixed* 200-genotype window still OOM'd, because 200 genotypes x 50k-100k markers/genotype is 10-20 million Perl hash entries in one window — the batch size bounded query count but not the thing that actually drives memory (total rows = genotypes-in-window x markers-per-genotype). Added `_bulk_fetch_window_size()` so the window shrinks as marker count grows: `min(_bulk_fetch_batch_size, _bulk_fetch_max_result_rows / markers_per_genotype)`, defaulting `_bulk_fetch_max_result_rows` to 1,000,000. For a 75k-marker protocol this yields a ~13-genotype window instead of 200 — more SQL round trips than originally hoped, but still far fewer than the pre-Phase-2 N+1 pattern, and memory now actually stays bounded.

### Phase 3: Additional Optimizations (Estimated: 2-3 days)

**Priority: MEDIUM**

#### 3.1 Protocol Metadata Query Consolidation
Combine the 4 separate protocol metadata queries into 1-2 queries.

**Current pattern (lines 1044-1076):** 4 separate executions per protocol

**Optimized approach:**
```sql
-- Single query for all protocol metadata
SELECT 
    nd_protocol_id,
    jsonb_object_agg(
        CASE type_id
            WHEN $markers_cvterm_id THEN 'markers'
            WHEN $markers_array_cvterm_id THEN 'markers_array'
            WHEN $details_cvterm_id THEN 'details'
        END,
        value
    ) AS protocol_data
FROM nd_protocolprop
WHERE nd_protocol_id = ANY(?::int[])
  AND type_id IN (?, ?, ?)
GROUP BY nd_protocol_id;
```

**Files to modify:**
- [lib/CXGN/Genotype/Search.pm](lib/CXGN/Genotype/Search.pm) lines 1044-1076

**Expected impact:** 4-12x reduction in protocol queries, saving 1-3 seconds

#### 3.2 Optimize Field Selection
For specific use cases (dosage matrix, GT-only), reduce JSONB fields fetched.

**Implementation:**
- Add parameter validation/warnings when many fields selected
- Document performance implications of field selection
- Consider separate optimized methods for common cases

**Files to modify:**
- [lib/CXGN/Genotype/Search.pm](lib/CXGN/Genotype/Search.pm) - add documentation
- Update POD documentation for performance guidance

**Expected impact:** 20-40% reduction in data transferred/parsed

### Phase 4: Advanced Optimization (Optional, Estimated: 5-7 days)

**Priority: LOW - Only if Phase 2 results are insufficient**

#### 4.1 Parallel Accession Processing
Parallelize accession processing using `Parallel::ForkManager` pattern from [GRM.pm](lib/CXGN/Genotype/GRM.pm).

**Approach:**
- Split accessions into chunks (e.g., 100 per chunk)
- Fork worker processes to handle chunks in parallel
- Each worker writes to separate temp file
- Parent concatenates chunk files before transposition

**Expected impact:** 2-4x speedup with 4 cores (on top of query optimization)

**Note:** This is only valuable AFTER implementing Phase 2. Database queries are the primary bottleneck, not CPU processing.

## Expected Performance Improvements

**Baseline:** 1000 genotypes, 50,000 markers = ~120-180 seconds (2-3 minutes)

| Phase | Time (seconds) | Improvement | Speedup |
|-------|---------------|-------------|---------|
| Current | 120-180 | baseline | 1x |
| After Phase 1 | 90-120 | 25-33% | 1.3-1.5x |
| After Phase 2 | 15-30 | 80-90% | 10-12x |
| After Phase 3 | 10-20 | 85-92% | 12-18x |
| After Phase 4 (optional) | 5-10 | 92-96% | 18-36x |

## Testing & Validation

**Note:** Since Phase 2 modifies `init_genotype_iterator()` / `get_next_genotype_info()` in place (no parallel `_optimized` methods), "before vs. after" comparisons below mean the current commit vs. the Phase 2 commit (e.g. via `git stash` / a throwaway branch), not two coexisting methods.

### Unit Tests

**Run the existing structural test first** — [t/unit_fixture/CXGN/Genotype/Search.t](t/unit_fixture/CXGN/Genotype/Search.t) already builds a `CXGN::Genotype::Search`, calls `init_genotype_iterator()` / `get_next_genotype_info()`, and does full `is_deeply()` comparisons of the returned hash (including `selected_genotype_hash` marker data) for 3 known accessions/genotypes against a `GBS ApeKI genotyping v4` protocol fixture. This must still pass unmodified after Phase 2 — it's the primary regression guard for output shape.

**Add new tests for `_bulk_fetch_genotypeprop_data()`** in the same file, using the same fixture accessions/protocol:
```perl
my $search = CXGN::Genotype::Search->new({
    bcs_schema => $schema,
    people_schema => $people_schema,
    accession_list => $ds->accessions(),
    protocol_id_list => [$protocol_id],
    genotypeprop_hash_select => ['DS'],
});
$search->init_genotype_iterator();
my $bulk_data = $search->_bulk_genotypeprop_data;

is(ref($bulk_data), 'HASH', 'Bulk data is a hash');
ok(scalar(keys %$bulk_data) > 0, 'Bulk data contains genotypes');

my ($first_genotype_id) = keys %$bulk_data;
is(ref($bulk_data->{$first_genotype_id}), 'HASH', 'Per-genotype marker data is a hash');
```

**Test edge cases:**
- Empty genotype_id list (should return empty hash without querying)
- A single genotype (batch loop must still run once)
- Genotype count exactly on a batch-size boundary and one over it (off-by-one in chunking)
- Filtered markers (`marker_name_list` / chromosome / position range — verify only requested markers come back)
- Multiple protocols in one search (verify marker data isn't cross-contaminated between genotypes)

### Correctness Tests (before vs. after this change)

**Byte-for-byte VCF comparison**, run once on the current commit and once after applying Phase 2:
```bash
git stash   # or check out the pre-Phase-2 commit
perl -e 'use CXGN::Genotype::Search;
    my $s = CXGN::Genotype::Search->new({...});
    my ($fh, $path) = $s->get_cached_file_VCF();
    print "$path\n";'   # save as before.vcf

git stash pop   # apply Phase 2 changes
perl -e '...same script...'   # save as after.vcf

diff before.vcf after.vcf   # should be identical (cache-key/timestamp lines aside)
```

**Test across scenarios:**
1. Single protocol, all markers
2. Multiple protocols
3. Filtered by chromosome (`chromosome_list => [1, 2, 3]`)
4. Filtered by marker names (`marker_name_list => [...]`)
5. Filtered by position range (`start_position` / `end_position`)
6. Different `genotypeprop_hash_select` options (GT only, DS only, all fields)
7. A dataset larger than one batch (e.g. `_bulk_fetch_batch_size` genotypes + 1) to exercise the chunking loop
8. Small dataset (the existing 3-accession fixture)

**Verify transposition still works:** marker-major temp file format, SLURM transpose step, and that the final VCF is valid (readable by `vcftools`/`bcftools`) — none of this changes in Phase 2, but it depends on `get_cached_file_VCF()`'s output being correct.

### Database Performance Tests

**Verify the composite index is used** (it already exists from Phase 1, commit `53bb6a8446`):
```sql
EXPLAIN ANALYZE
SELECT genotypeprop.genotype_id, s.key, s.value->>'GT'
FROM genotypeprop, jsonb_each(genotypeprop.value) as s
WHERE genotypeprop.genotype_id IN (/* batch of ids */)
  AND s.key != 'CHROM'
  AND type_id = 75920;
```
Look for `Index Scan using idx_genotypeprop_genotype_type` in the plan, and confirm query count drops from one-per-genotype to one-per-batch (log queries via `DBI_TRACE` or Postgres `log_statement` during a test download).

### Memory Tests

Since each genotype's JSONB blob can unpack to tens of thousands of `jsonb_each` rows, confirm batching actually bounds memory:
```perl
use Memory::Usage;
my $mu = Memory::Usage->new();
$mu->record('startup');
my $search = CXGN::Genotype::Search->new({...});
$mu->record('after init');   # this is where the bulk fetch now happens
my ($fh, $path) = $search->get_cached_file_VCF();
$mu->record('after VCF generation');
$mu->dump();
```
Try `_bulk_fetch_batch_size` at 100, 200 (default), and 500 on a large dataset and confirm memory doesn't grow unboundedly as batch size increases — tune the default down if 200 is already too large for typical marker counts in production.

## Implementation Considerations

### Backward Compatibility
- Keep existing public API unchanged
- Add new internal methods for optimization
- Maintain iterator pattern interface
- No breaking changes to callers

### Monitoring
Add instrumentation for:
- Query execution times
- Query counts per download
- Memory usage peaks
- Batch sizes used

### Rollout Strategy
1. Deploy Phase 1 first (low risk) — done (commits `53bb6a8446`, `c12330bedf`)
2. Deploy Phase 2 directly (in-place change, no feature flag — see "Rollout strategy" under Implementation Decisions below for why) — done (commit `b30459f2a6`)
3. Monitor production performance and memory usage — not yet done
4. Deploy Phase 3 after Phase 2 validation — not started
5. Only implement Phase 4 if needed — not started

## Controller Integration

**Superseded (2026-07-27):** Phase 2 modifies `init_genotype_iterator()` / `get_next_genotype_info()` in place rather than adding a parallel `get_cached_file_VCF_optimized()` method, so no caller/controller changes are needed — `get_cached_file_VCF()` and every other existing entry point automatically get the bulk-query behavior. The size-based/config-based selection options originally sketched here are not needed.

## Critical Files

**Primary modifications:**
- [lib/CXGN/Genotype/Search.pm](lib/CXGN/Genotype/Search.pm) - main optimization target
  - Modify in place: `init_genotype_iterator()`, `get_next_genotype_info()` (no changes needed to `get_genotype_info()` or `get_cached_file_VCF()` — they call into the two methods above and are unaffected otherwise)
  - Add: `_bulk_fetch_genotypeprop_data()` method, `_bulk_genotypeprop_data` attribute, `_bulk_fetch_batch_size` attribute
  - Remove: `_iterator_genotypeprop_query_handle` attribute, `_genotypeprop_h` attribute (and the prepared statements that populated them)

**Reference implementations:**
- `_bulk_synonym_data` / the bulk synonym fetch added in `init_genotype_iterator()` (commit `c12330bedf`) is the pattern to follow for `_bulk_genotypeprop_data` — same file, same "collect IDs during the row loop, fetch once, store in a `rw` HashRef attribute" shape.
- [lib/CXGN/Stock/StockLookup.pm](lib/CXGN/Stock/StockLookup.pm) - `get_stock_synonyms()`, the bulk-fetch method that pattern is based on.
- [lib/CXGN/Genotype/GRM.pm](lib/CXGN/Genotype/GRM.pm) - parallel processing pattern (only relevant if Phase 4 is ever needed)

**Database migrations:**
- None needed for Phase 2 — the required `(genotype_id, type_id)` index already exists from Phase 1 (`db/00207/AddGenotypepropIndexes.pm`).

## Success Criteria

### Phase 1 Success
- [x] Database indexes verified and created (`db/00207/AddGenotypepropIndexes.pm`, commit `53bb6a8446`)
- [x] Synonym queries reduced from 1000 to 1 for 1000-genotype download (`_bulk_synonym_data`, commit `c12330bedf`)
- [ ] 25-33% performance improvement measured
- [ ] No memory regressions
- [ ] All existing tests pass

### Phase 2 Success
- [x] Bulk `genotype_id IN (...)` query implementation complete, batched via `_bulk_fetch_batch_size` (commit `b30459f2a6`)
- [x] Nested N+1 queries eliminated (2000-4000 queries → ~`ceil(G/batch_size)` queries) — `_iterator_genotypeprop_query_handle` / `_genotypeprop_h` removed, `get_next_genotype_info()` now reads from `_bulk_genotypeprop_data`
- [ ] 80-90% total performance improvement from baseline
- [ ] Memory usage <2GB for 1000 genotypes (windowed fetch fixing the eager-fetch OOM regression implemented 2026-07-31 — see "Correction" note above; still needs to be measured)
- [ ] VCF output matches pre-Phase-2 output byte-for-byte (see Correctness Tests)
- [ ] [t/unit_fixture/CXGN/Genotype/Search.t](t/unit_fixture/CXGN/Genotype/Search.t) and all other existing tests pass unmodified

### Phase 3 Success
- [ ] Protocol queries consolidated
- [ ] 85-92% total performance improvement
- [ ] Documentation updated with performance guidance
- [ ] All tests pass

## Risks & Mitigations

| Risk | Impact | Mitigation |
|------|--------|------------|
| Memory exhaustion with bulk queries | High | Batch by `_bulk_fetch_batch_size` (default 200); tune down if a batch's `jsonb_each` expansion is still too large |
| Output differs from original | Critical | Existing `Search.t` `is_deeply()` assertions + before/after byte-for-byte VCF comparison (no parallel fallback method is kept, so this testing is the safety net) |
| Database performance regression | Medium | Composite index already in place (Phase 1); verify with `EXPLAIN ANALYZE` before merging |
| Complex debugging of parallel code | Medium | Only implement Phase 4 if absolutely needed |

## Implementation Decisions

Based on user requirements:

1. **Typical dataset sizes:** Large (2k-10k accessions, 50-100k markers)
   - This confirms the critical need for Phase 2 bulk query optimization
   - Memory batching will be important (process in chunks of 200-500)
   - Expected improvement from 3-5 minutes down to 15-30 seconds

2. **Priority:** Implement Phases 1 + 2 (maximum impact, 80-90% improvement)
   - Phase 1: Foundation (indexes + bulk synonyms)
   - Phase 2: Bulk JSONB query optimization
   - Phase 3: Deferred for future iteration
   - Phase 4: Not needed at this time

3. **Rollout strategy (revised 2026-07-27):** Modify in place
   - Original plan called for a separate `get_cached_file_VCF_optimized()` method kept side-by-side with the original for gradual adoption.
   - Revised after investigation: the fix is a same-shape SQL change (batch `genotype_id IN (...)` instead of per-genotype/per-genotypeprop-id queries), the output structure is unchanged, and [t/unit_fixture/CXGN/Genotype/Search.t](t/unit_fixture/CXGN/Genotype/Search.t) already asserts the exact output shape — so `init_genotype_iterator()` / `get_next_genotype_info()` are modified directly instead of duplicating ~700 lines across three methods.
   - No controller changes needed (see revised "Controller Integration" section below).
