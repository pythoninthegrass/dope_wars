/* Tier-C conformance driver (TASK-001.05 AC#2, C side).

This TU's job is the half the ctypes harness structurally cannot do: prove that
include/dopewars.h is self-consistent as C. Every struct in it carries a
DW_STATIC_ASSERT, and that expands to _Static_assert, which fires at compile
time -- so if this file compiles at all, the header's layouts are what the
contract says they are. A Python-side size table can never assert that; it can
only agree or disagree with itself.

It also proves two things the ctypes harness depends on:

  1. The header is includable standalone in C11 with no prior include (a
     consumer must be able to take just this one header, per its own comment).
  2. Every dw_* symbol listed below is link-resolvable, by taking its address.
     Taking the address does not call the function, so this compiles and links
     against a library that exports the listed set.

Assertions use the header's own DW_STATIC_ASSERT rather than the raw
_Static_assert keyword. Same expansion, but it keeps this file spelling the
contract the way the rest of the repo does -- and a header that ever dropped the
macro would then fail to build here instead of silently diverging.

No runtime assertions live here beyond the compile-time ones; readable failures
belong in the Python harness. Run through task core:abi-header-check.
*/

#include "dopewars.h"

#include <stddef.h>
#include <stdint.h>

/* The header must define its own dimensional contract, and the test-side
 * constants must agree with it. These are compile-time: a disagreement stops
 * the build rather than turning into a wrong-length buffer at runtime. */
DW_STATIC_ASSERT(DW_ABI_VERSION == 7u, "DW_ABI_VERSION drifted from the v7 contract");
DW_STATIC_ASSERT(DW_NUM_LOCATIONS == 6u, "DW_NUM_LOCATIONS drifted");
DW_STATIC_ASSERT(DW_NUM_DRUGS == 12u, "DW_NUM_DRUGS drifted");
DW_STATIC_ASSERT(DW_MAX_HIGHSCORES == 10u, "DW_MAX_HIGHSCORES drifted");

/* Result codes are frozen integers, not a C enum, precisely so their width is
 * defined. Assert the width and the values every consumer switches on. */
DW_STATIC_ASSERT(sizeof(dw_result) == 4, "dw_result must stay int32_t sized");
DW_STATIC_ASSERT(DW_OK == 0, "DW_OK must be zero: default-constructed reads success");
DW_STATIC_ASSERT(DW_ERR_INVALID_ARGUMENT == 1, "result code renumbered");
DW_STATIC_ASSERT(DW_ERR_BUFFER_TOO_SMALL == 2, "result code renumbered");
DW_STATIC_ASSERT(DW_ERR_ABI_VERSION_MISMATCH == 3, "result code renumbered");
DW_STATIC_ASSERT(DW_ERR_SERIALIZATION_FAILED == 13, "result code renumbered");

/* Kind enums are uint8_t typedefs for the same width reason. */
DW_STATIC_ASSERT(sizeof(dw_arrival_event_kind) == 1, "arrival kind must stay uint8_t");
DW_STATIC_ASSERT(sizeof(dw_price_event_kind) == 1, "price event kind must stay uint8_t");
DW_STATIC_ASSERT(sizeof(dw_finances_action) == 1, "finances action must stay uint8_t");
DW_STATIC_ASSERT(sizeof(dw_dealer_kind) == 1, "dealer kind must stay uint8_t");

/* dw_world stays opaque: callers hold a pointer only. Assert the contract's
 * shape rather than its size, which must remain unknown here. */
DW_STATIC_ASSERT(sizeof(dw_world *) == sizeof(void *), "dw_world must be a pointer");

/* The offsets a caller would hard-code if it ever memcpy'd a partial struct.
 * Sizes are asserted in the header; these pin the interior layout that the
 * two-call copies write field by field. */
/* Every field offset in dw_state_view, pinned rather than spot-checked. The
 * header asserts the struct's size (56B), but a size assert alone still passes
 * if a field is reordered behind padding -- and a reordered field is silent data
 * corruption for a caller that fills the struct field by field, which is exactly
 * what dw_state_get is contractually required to do. Pinning all twelve offsets
 * makes the interior layout as frozen as its total size.
 *
 * The gaps at 12 and 54 are alignment padding before the two int64_t fields and
 * the trailing specified-zero pad respectively; they are implied by the offsets
 * either side of them and are not asserted separately. */
DW_STATIC_ASSERT(offsetof(dw_state_view, day) == 0, "dw_state_view.day must be first");
DW_STATIC_ASSERT(offsetof(dw_state_view, num_days) == 4, "dw_state_view.num_days offset changed");
DW_STATIC_ASSERT(offsetof(dw_state_view, cash) == 8, "dw_state_view.cash offset changed");
DW_STATIC_ASSERT(offsetof(dw_state_view, bank) == 16, "dw_state_view.bank offset changed");
DW_STATIC_ASSERT(offsetof(dw_state_view, debt) == 24, "dw_state_view.debt offset changed");
DW_STATIC_ASSERT(offsetof(dw_state_view, health) == 32, "dw_state_view.health offset changed");
DW_STATIC_ASSERT(
    offsetof(dw_state_view, coat_capacity) == 36, "dw_state_view.coat_capacity offset changed"
);
DW_STATIC_ASSERT(
    offsetof(dw_state_view, coat_used) == 40, "dw_state_view.coat_used offset changed"
);
DW_STATIC_ASSERT(offsetof(dw_state_view, guns) == 44, "dw_state_view.guns offset changed");
DW_STATIC_ASSERT(
    offsetof(dw_state_view, location_index) == 48, "dw_state_view.location_index offset changed"
);
DW_STATIC_ASSERT(offsetof(dw_state_view, dead) == 52, "dw_state_view.dead offset changed");
DW_STATIC_ASSERT(
    offsetof(dw_state_view, last_day_warned) == 53, "dw_state_view.last_day_warned offset changed"
);

/* dw_config is the other struct a caller constructs before any call happens, so
 * its two fields are pinned the same way. sizeof == 8 is asserted in the header.
 */
DW_STATIC_ASSERT(offsetof(dw_config, abi_version) == 0, "dw_config.abi_version must be first");
DW_STATIC_ASSERT(offsetof(dw_config, rng_seed) == 4, "dw_config.rng_seed offset changed");

/* Taking a declared function's address is resolved at link time. This lists the
 * pointer-free declarations, i.e. the ones core/src/abi.mojo can export on Mojo
 * 1.1.0; the pointer-taking set is accounted for by the Python harness's blocked
 * list (docs/mojo-1.1.0-abi-constraints.md). When the toolchain lifts the limit,
 * this is where they get added back -- and the Python test that fails first will
 * point here. */
static void *const dw_implemented_surface[] = {
    (void *) &dw_abi_version,
    (void *) &dw_rules_default_num_days,
    (void *) &dw_rules_default_start_cash,
    (void *) &dw_rules_default_start_debt,
    (void *) &dw_rules_default_start_health,
    (void *) &dw_rules_default_start_coat_capacity,
    (void *) &dw_rules_default_start_location_index,
    (void *) &dw_rules_gun_damage,
    (void *) &dw_rules_player_armor,
    (void *) &dw_rules_debt_interest_bp,
    (void *) &dw_rules_bank_interest_bp,
    (void *) &dw_rules_cheap_divide,
    (void *) &dw_rules_expensive_multiply,
    (void *) &dw_rules_locations_len,
    (void *) &dw_rules_drugs_len,
    (void *) &dw_world_align,
    (void *) &dw_world_dump_len,
};

#define DW_ARRAY_LEN(a) (sizeof(a) / sizeof((a)[0]))

/* main() exists so the task runner can link and run this as a binary. The
 * meaningful checks already happened at compile time; the runtime loop only
 * confirms every taken address is non-null and that one live call through the
 * header's prototype returns the value the header's macro promises. */
int
main(void)
{
    for (size_t i = 0; i < DW_ARRAY_LEN(dw_implemented_surface); i += 1) {
        if (dw_implemented_surface[i] == NULL) {
            return 1;
        }
    }
    return dw_abi_version() == DW_ABI_VERSION ? 0 : 1;
}
