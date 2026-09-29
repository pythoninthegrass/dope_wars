/*
 * dopewars.h — the frozen C ABI contract for the Dope Wars Mojo simulation
 * core (TASK-001.01).
 *
 * This is the ONLY header any consumer (the C++ GDExtension shim in
 * `extension/`, any future native binding, a conformance test) is allowed
 * to depend on. `core/` is the only place that exports the dw_* symbols
 * declared here, and every export it makes must have a matching
 * declaration in this file — nothing more, nothing less. See
 * `docs/abi-contract.md` for the discipline and `docs/layer-boundaries.md`
 * for what each layer is and is not allowed to do.
 *
 * Modeled on `~/git/jumpnbump/include/jumpnbump.h`'s discipline: opaque
 * caller-owned world handle, uint8_t/int32_t-typedef'd value spaces (never
 * a bare C enum crossing the ABI, since a C enum's underlying integer
 * width is unspecified), a DW_STATIC_ASSERT on every ABI struct's sizeof,
 * and a two-call length-then-fill convention for every buffer whose
 * required length isn't a compile-time constant.
 *
 * ---------------------------------------------------------------------
 * Divergence from jumpnbump: bidirectional serialize/load
 * ---------------------------------------------------------------------
 * jumpnbump's ABI deliberately omits a load/deserialize function because
 * the ported Zig core only implements dumpTo(). Dope Wars differs: the JS
 * prototype at `index.html:1033-1047` round-trips through JSON with
 * serializeState/deserializeState, and the save-slot feature depends on
 * that round-trip. The Mojo port therefore implements both directions from
 * day one, and `dw_world_load` is part of this frozen contract.
 *
 * Bit-for-bit round-trip is a requirement: dumping, loading, and dumping
 * again must produce identical bytes at the same DW_ABI_VERSION.
 */

#ifndef DOPEWARS_H
#define DOPEWARS_H

#include <stddef.h>
#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

#if defined(__cplusplus)
#define DW_STATIC_ASSERT(cond, msg) static_assert(cond, msg)
#else
#define DW_STATIC_ASSERT(cond, msg) _Static_assert(cond, msg)
#endif

/* ---------------------------------------------------------------------- */
/* Versioning                                                              */
/* ---------------------------------------------------------------------- */

/* Bump on any change to this header's function signatures, calling
 * convention, struct layouts, exported semantics, or RNG draw order for a
 * given seed. Every binding must be rebuilt and relinked when this
 * changes. Additive changes (new functions, new appended anonymous-enum
 * constants, new `#define`s that don't invalidate existing struct sizes)
 * do NOT bump this. See `docs/abi-contract.md` for the full policy. */
#define DW_ABI_VERSION 2u

/* The value above, readable at runtime.
 *
 * A C consumer reads DW_ABI_VERSION as a #define and never needs this. It
 * exists for consumers that link against the library without the header's
 * preprocessor in the way — GDExtension's BIND_CONSTANT path, a scripting
 * binding, or a shipped .so whose compile-time constant may predate the
 * binary. A binding should compare dw_abi_version() against DW_ABI_VERSION and
 * refuse to run on mismatch rather than trust that the header it was built
 * with matches the library it is loading.
 *
 * Declared here so the exporter in core/src/abi.mojo has something to match:
 * every dw_* symbol the library defines must be declared in this header, which
 * is what tools/check_abi_exports.py enforces in both directions. Before this
 * declaration existed, extension/src/dopewars_world.cpp had an ad-hoc
 * `extern "C" uint32_t dw_abi_version(void);`, which is precisely the
 * header-is-the-contract violation the gate is for. */
uint32_t dw_abi_version(void);

/* Frozen simulation dimensions, mirroring `index.html:641-681`'s RULES.
 * Every ABI struct below is sized against these. */
#define DW_NUM_LOCATIONS 6u
#define DW_NUM_DRUGS 12u
#define DW_MAX_HIGHSCORES 10u

/* Maximum length (bytes, including the trailing NUL) of the fixed-size
 * UTF-8 char arrays that carry short identifiers across the ABI. */
#define DW_MAX_LOCATION_ID_LEN 32u
#define DW_MAX_LOCATION_NAME_LEN 32u
#define DW_MAX_DRUG_ID_LEN 32u
#define DW_MAX_DRUG_NAME_LEN 32u
#define DW_MAX_HIGHSCORE_NAME_LEN 32u

/* ---------------------------------------------------------------------- */
/* Result codes                                                            */
/*                                                                         */
/* Plain int32_t, not a C enum: a C enum's underlying integer width is     */
/* unspecified by the language, which is exactly the ambiguity a frozen    */
/* cross-language (C / C++ / Mojo / GDExtension) ABI cannot afford.        */
/* ---------------------------------------------------------------------- */

typedef int32_t dw_result;

enum {
    DW_OK = 0,
    /* An out-of-range or malformed argument: an unknown drug/location id,
     * a null pointer where a non-null one was required, etc. */
    DW_ERR_INVALID_ARGUMENT = 1,
    /* An output buffer's capacity was smaller than the required length.
     * The call still reports the true required length so the caller can
     * retry (the two-call length-then-fill contract; see e.g.
     * dw_prices_copy, dw_inventory_copy, dw_world_dump). */
    DW_ERR_BUFFER_TOO_SMALL = 2,
    /* config->abi_version did not equal DW_ABI_VERSION. */
    DW_ERR_ABI_VERSION_MISMATCH = 3,
    /* dw_find_location_index / dw_travel: the given id is not one of the
     * DW_NUM_LOCATIONS locations. */
    DW_ERR_UNKNOWN_LOCATION = 4,
    /* dw_find_drug_index / dw_buy / dw_sell: the given id is not one of
     * the DW_NUM_DRUGS drugs. */
    DW_ERR_UNKNOWN_DRUG = 5,
    /* dw_buy / dw_sell: the drug is a valid drug but is not on the
     * current location's price list this turn. */
    DW_ERR_NOT_TRADED_HERE = 6,
    /* dw_buy / dw_finances(deposit) / dw_accept_*_offer: not enough cash
     * on hand to complete the transaction. */
    DW_ERR_INSUFFICIENT_CASH = 7,
    /* dw_finances(withdraw) / dw_accept_*_offer bank fallback: not enough
     * in the bank to complete the transaction (including the bank
     * purchase fee, where applicable). */
    DW_ERR_INSUFFICIENT_BANK = 8,
    /* dw_sell: fewer units held than the caller tried to sell. */
    DW_ERR_INSUFFICIENT_INVENTORY = 9,
    /* dw_buy / dw_accept_gun_offer: not enough coat space to hold the
     * new inventory or gun. */
    DW_ERR_INSUFFICIENT_SPACE = 10,
    /* dw_travel / dw_generate_prices: the game has already reached
     * numDays and no further turns are allowed. */
    DW_ERR_GAME_OVER = 11,
    /* Any turn-driving call after the player has died. */
    DW_ERR_DEAD = 12,
    /* dw_world_load: byte sequence is not a valid dump for this ABI
     * version (wrong length, corrupt scalars, unknown location/drug id in
     * the payload). */
    DW_ERR_SERIALIZATION_FAILED = 13,
};

/* ---------------------------------------------------------------------- */
/* Kind enums (uint8_t-typedef'd, never bare C enum)                       */
/* ---------------------------------------------------------------------- */

/* dw_arrival_event.kind — see `index.html:869-927` for the JS oracle's
 * percentile roll table. DW_ARRIVAL_NONE means the roll landed in the
 * no-event band (>=75%) or the branch degenerated to "nothing happens"
 * (e.g. free-drugs branch with no tradeable drug or no coat space). */
typedef uint8_t dw_arrival_event_kind;
enum {
    DW_ARRIVAL_NONE = 0,
    DW_ARRIVAL_MUGGED = 1,
    DW_ARRIVAL_FREE_DRUGS = 2,
    DW_ARRIVAL_DOG_CHASE = 3,
    DW_ARRIVAL_FOUND_DRUGS = 4,
    DW_ARRIVAL_MAMAS_BROWNIES = 5,
    DW_ARRIVAL_FREE_WEED_DEATH = 6,
    DW_ARRIVAL_FLAVOR = 7,
};

/* dw_price_event.kind — see `index.html:742,745` for the JS oracle's two
 * price-event bands. */
typedef uint8_t dw_price_event_kind;
enum {
    DW_PRICE_EVENT_CHEAP = 0,
    DW_PRICE_EVENT_EXPENSIVE = 1,
};

/* dw_finances action selector. */
typedef uint8_t dw_finances_action;
enum {
    DW_FINANCES_DEPOSIT = 0,
    DW_FINANCES_WITHDRAW = 1,
    DW_FINANCES_PAY_LOAN = 2,
};

/* ---------------------------------------------------------------------- */
/* Opaque world handle                                                     */
/* ---------------------------------------------------------------------- */

/* Never defined — callers only ever hold a pointer. The caller allocates
 * dw_world_size() bytes aligned to dw_world_align() and passes that
 * storage to dw_world_init(); nothing on this side of the ABI allocates
 * on the caller's behalf, and there is deliberately no dw_world_destroy
 * (adding one later is additive; removing one later is not). */
typedef struct dw_world dw_world;

/* ---------------------------------------------------------------------- */
/* Config                                                                  */
/* ---------------------------------------------------------------------- */

typedef struct dw_config {
    uint16_t abi_version;  /* must equal DW_ABI_VERSION */
    uint16_t _pad0;         /* specified-zero; pads rng_seed to a 4-byte offset */
    uint32_t rng_seed;      /* mulberry32 seed; may be any uint32_t */
    uint32_t num_days;      /* 0 means "use the ruleset default of 31" */
    int32_t  start_cash;    /* negative sentinel (-1) means "use ruleset default" */
} dw_config;
DW_STATIC_ASSERT(sizeof(dw_config) == 16, "dw_config layout changed");

/* ---------------------------------------------------------------------- */
/* Rule table views                                                        */
/*                                                                         */
/* Static-once tables the caller reads through two-call length-then-fill.  */
/* Both tables are frozen at DW_NUM_LOCATIONS / DW_NUM_DRUGS, so the       */
/* required-length query always reports that constant.                     */
/* ---------------------------------------------------------------------- */

typedef struct dw_location_view {
    char     id[DW_MAX_LOCATION_ID_LEN];
    char     name[DW_MAX_LOCATION_NAME_LEN];
    uint32_t police;      /* police presence weight; see dw_should_start_chase */
    uint32_t min_drugs;   /* minimum count of drugs traded on any turn here */
    uint32_t max_drugs;   /* maximum count of drugs traded on any turn here */
    uint32_t _pad0;       /* specified-zero */
} dw_location_view;
DW_STATIC_ASSERT(sizeof(dw_location_view) == 80, "dw_location_view layout changed");

typedef struct dw_drug_view {
    char     id[DW_MAX_DRUG_ID_LEN];
    char     name[DW_MAX_DRUG_NAME_LEN];
    int32_t  min_price;
    int32_t  max_price;
    uint8_t  cheap;       /* 0 or 1; can appear as a cheap price event */
    uint8_t  expensive;   /* 0 or 1; can appear as an expensive price event */
    uint8_t  _pad0[2];    /* specified-zero */
} dw_drug_view;
DW_STATIC_ASSERT(sizeof(dw_drug_view) == 76, "dw_drug_view layout changed");

/* ---------------------------------------------------------------------- */
/* Live-state views                                                        */
/* ---------------------------------------------------------------------- */

typedef struct dw_state_view {
    uint32_t day;              /* 1-based; day 1 is the first turn */
    uint32_t num_days;         /* copied from dw_config or the ruleset default */
    int32_t  cash;
    int64_t  bank;             /* accrues compound interest; may exceed int32 */
    int64_t  debt;             /* accrues compound interest; may exceed int32 */
    int32_t  health;           /* 0..100 */
    int32_t  coat_capacity;    /* current total slots (starts at 100) */
    int32_t  coat_used;        /* denormalized for query convenience */
    uint32_t guns;
    uint32_t location_index;   /* < DW_NUM_LOCATIONS */
    uint8_t  dead;             /* 0 or 1 */
    uint8_t  last_day_warned;  /* UI orchestration flag */
    uint8_t  _pad0[2];         /* specified-zero */
} dw_state_view;
DW_STATIC_ASSERT(sizeof(dw_state_view) == 56, "dw_state_view layout changed");

/* One entry in a two-call inventory copy. Slots with qty == 0 are
 * omitted from the copy (the required length is the count of live
 * slots, not DW_NUM_DRUGS). avg_price uses fixed-point cents so the
 * ABI carries no floating-point across the boundary. */
typedef struct dw_inventory_slot {
    uint32_t drug_index;       /* < DW_NUM_DRUGS */
    uint32_t qty;
    int64_t  avg_price_cents;  /* running average buy price, in cents */
} dw_inventory_slot;
DW_STATIC_ASSERT(sizeof(dw_inventory_slot) == 16, "dw_inventory_slot layout changed");

/* One entry in a two-call price-list copy. Only drugs actually traded at
 * the current location this turn appear; the required length is the
 * count of traded drugs. `was_event` marks a slot whose price came from
 * a cheap/expensive event roll rather than the normal min..max band. */
typedef struct dw_price_slot {
    uint32_t drug_index;       /* < DW_NUM_DRUGS */
    int32_t  price;
    uint8_t  was_event;        /* 0 or 1 */
    uint8_t  _pad0[3];         /* specified-zero */
} dw_price_slot;
DW_STATIC_ASSERT(sizeof(dw_price_slot) == 12, "dw_price_slot layout changed");

/* One cheap/expensive price event surfaced by dw_generate_prices. */
typedef struct dw_price_event {
    dw_price_event_kind kind;
    uint8_t             _pad0[3];   /* specified-zero */
    uint32_t            drug_index; /* < DW_NUM_DRUGS */
} dw_price_event;
DW_STATIC_ASSERT(sizeof(dw_price_event) == 8, "dw_price_event layout changed");

/* One arrival event (structured payload only — presentation strings live
 * in GDScript, not in this ABI). Field usage by kind:
 *   MUGGED           -> amount = dollars lost (or damage taken if cash==0),
 *                       damage = HP lost when the "cashless mugging" path
 *                       fires, otherwise 0.
 *   FREE_DRUGS       -> drug_index, qty granted.
 *   DOG_CHASE        -> drug_index, qty lost.
 *   FOUND_DRUGS      -> drug_index, qty granted.
 *   MAMAS_BROWNIES   -> drug_index (weed or hashish), qty lost.
 *   FREE_WEED_DEATH  -> no payload; player is now dead.
 *   FLAVOR           -> amount = dollars spent on food.
 *   NONE             -> no payload. */
typedef struct dw_arrival_event {
    dw_arrival_event_kind kind;
    uint8_t               _pad0[3];   /* specified-zero */
    uint32_t              drug_index; /* < DW_NUM_DRUGS when meaningful */
    int32_t               qty;
    int32_t               amount;
    int32_t               damage;
    int32_t               _pad1;      /* specified-zero */
} dw_arrival_event;
DW_STATIC_ASSERT(sizeof(dw_arrival_event) == 24, "dw_arrival_event layout changed");

/* ---------------------------------------------------------------------- */
/* Dealer offers                                                           */
/* ---------------------------------------------------------------------- */

typedef struct dw_coat_offer {
    uint32_t pockets;    /* extra coat slots on acceptance */
    int32_t  price;      /* dollars */
} dw_coat_offer;
DW_STATIC_ASSERT(sizeof(dw_coat_offer) == 8, "dw_coat_offer layout changed");

typedef struct dw_gun_offer {
    int32_t  price;      /* dollars */
    uint32_t damage;     /* per-gun damage; see dw_get_fight_ratings */
    uint32_t space;      /* coat slots consumed per gun */
    uint32_t _pad0;      /* specified-zero */
} dw_gun_offer;
DW_STATIC_ASSERT(sizeof(dw_gun_offer) == 16, "dw_gun_offer layout changed");

/* Populated by dw_accept_coat_offer / dw_accept_gun_offer. `used_bank`
 * indicates the price was drawn from the bank (with the bank purchase
 * fee applied); `fee` is 0 when used_bank is 0. */
typedef struct dw_purchase_result {
    uint8_t  used_bank;   /* 0 or 1 */
    uint8_t  _pad0[3];    /* specified-zero */
    int32_t  fee;         /* dollars; 0 when used_bank == 0 */
} dw_purchase_result;
DW_STATIC_ASSERT(sizeof(dw_purchase_result) == 8, "dw_purchase_result layout changed");

/* ---------------------------------------------------------------------- */
/* Chase / combat                                                          */
/* ---------------------------------------------------------------------- */

typedef struct dw_chase {
    uint32_t deputies;    /* >= 0; when 0 the chase is won */
    uint8_t  can_fight;   /* 0 or 1; equals (guns > 0) at start_chase time */
    uint8_t  _pad0[3];    /* specified-zero */
} dw_chase;
DW_STATIC_ASSERT(sizeof(dw_chase) == 8, "dw_chase layout changed");

typedef struct dw_fight_ratings {
    uint32_t attack;
    uint32_t defend;
} dw_fight_ratings;
DW_STATIC_ASSERT(sizeof(dw_fight_ratings) == 8, "dw_fight_ratings layout changed");

/* Populated by dw_run_from_chase. */
typedef struct dw_run_result {
    uint8_t  escaped;      /* 0 or 1 */
    uint8_t  _pad0[3];     /* specified-zero */
    int32_t  damage_taken; /* 0 when escaped */
} dw_run_result;
DW_STATIC_ASSERT(sizeof(dw_run_result) == 8, "dw_run_result layout changed");

/* Populated by dw_fight. `won` means the last deputy just fell.
 * `dead` means the player's health hit zero on this exchange. `hit`
 * distinguishes a successful attack roll from a whiff-then-take-damage
 * result (see `index.html:1005-1019`). */
typedef struct dw_fight_result {
    uint8_t  hit;          /* 0 or 1 */
    uint8_t  dead;         /* 0 or 1 */
    uint8_t  won;          /* 0 or 1 */
    uint8_t  _pad0;        /* specified-zero */
    int32_t  damage_taken; /* 0 when hit == 1 */
} dw_fight_result;
DW_STATIC_ASSERT(sizeof(dw_fight_result) == 8, "dw_fight_result layout changed");

/* ---------------------------------------------------------------------- */
/* Endgame                                                                 */
/* ---------------------------------------------------------------------- */

typedef struct dw_finish_result {
    int64_t score;  /* cash + bank - debt */
    uint32_t day;   /* day at which the game ended */
    uint8_t  dead;  /* 0 or 1 */
    uint8_t  _pad0[3]; /* specified-zero */
} dw_finish_result;
DW_STATIC_ASSERT(sizeof(dw_finish_result) == 16, "dw_finish_result layout changed");

typedef struct dw_highscore_entry {
    char    name[DW_MAX_HIGHSCORE_NAME_LEN];
    int64_t score;
    uint32_t day;
    uint8_t  dead;
    uint8_t  _pad0[3]; /* specified-zero */
} dw_highscore_entry;
DW_STATIC_ASSERT(sizeof(dw_highscore_entry) == 48, "dw_highscore_entry layout changed");

/* ---------------------------------------------------------------------- */
/* RULES accessors                                                         */
/*                                                                         */
/* Exposed as free functions rather than as one mega-struct so future      */
/* additive rule changes don't have to bump DW_ABI_VERSION. Callers cache  */
/* these once at startup; they are pure and reentrant.                     */
/* ---------------------------------------------------------------------- */

uint32_t dw_rules_default_num_days(void);
int32_t  dw_rules_default_start_cash(void);
int64_t  dw_rules_default_start_debt(void);
int32_t  dw_rules_default_start_health(void);
int32_t  dw_rules_default_start_coat_capacity(void);
int32_t  dw_rules_default_start_location_index(void);
uint32_t dw_rules_gun_damage(void);
uint32_t dw_rules_gun_space(void);
uint32_t dw_rules_player_armor(void);
/* Fixed-point interest rates: numerator over 10000. debt = 1000 -> 10.00%. */
uint32_t dw_rules_debt_interest_bp(void);
uint32_t dw_rules_bank_interest_bp(void);
/* Bank purchase fee applied when a dealer offer is paid from the bank.
 * bp = numerator over 10000; 2500 -> 25.00%. */
uint32_t dw_rules_bank_purchase_fee_bp(void);
/* Cheap/expensive event multipliers. */
uint32_t dw_rules_cheap_divide(void);
uint32_t dw_rules_expensive_multiply(void);

/* Two-call length-then-fill. Required length is always DW_NUM_LOCATIONS
 * / DW_NUM_DRUGS respectively. Returns DW_ERR_BUFFER_TOO_SMALL if
 * out_capacity is smaller (still setting *out_required). */
dw_result dw_rules_locations_copy(dw_location_view *out_locations, size_t out_capacity, size_t *out_required);
dw_result dw_rules_drugs_copy(dw_drug_view *out_drugs, size_t out_capacity, size_t *out_required);

/* Length queries for the two copies above, as free functions.
 *
 * Additive (does not bump DW_ABI_VERSION — see the policy at the top of this
 * header). They exist because the required length of both buffers is a
 * compile-time constant, so the first call of the two-call convention does not
 * need an out-pointer to be answerable, and a caller that only has to size an
 * allocation can do so without a world handle. The values are exactly
 * DW_NUM_LOCATIONS and DW_NUM_DRUGS, and the conformance test asserts the
 * functions, the macros, and dw_rules_*_copy's *out_required all agree. */
uint32_t dw_rules_locations_len(void);
uint32_t dw_rules_drugs_len(void);

/* ---------------------------------------------------------------------- */
/* RNG (mulberry32)                                                        */
/*                                                                         */
/* Free-standing exposure so the JS oracle in tests/engine.test.mjs can    */
/* be compared bit-for-bit against the Mojo core for a given seed and     */
/* draw order (TASK-001.02). The dw_world handle owns its own separate    */
/* RNG stream, seeded from dw_config.rng_seed; turn-driving functions    */
/* draw from that stream, not these free functions.                       */
/* ---------------------------------------------------------------------- */

/* Initializes *out_state with the given seed. Semantics match the JS
 * mulberry32 factory at `index.html:624-635` — the state is the seed
 * unmodified, cast to uint32_t. */
void dw_mulberry32_seed(uint32_t seed, uint32_t *out_state);

/* Advances *state one step and returns the raw uint32_t draw. The JS
 * oracle returns a normalized double via `raw / 4294967296`; consumers
 * that need that normalization do it themselves. */
uint32_t dw_mulberry32_next_u32(uint32_t *state);

/* Inclusive integer range draw, matching `index.html:637-639`. Requires
 * min <= max; violation returns DW_ERR_INVALID_ARGUMENT without
 * advancing state. */
dw_result dw_rand_int(uint32_t *state, int32_t min, int32_t max, int32_t *out_value);

/* ---------------------------------------------------------------------- */
/* World lifecycle                                                         */
/* ---------------------------------------------------------------------- */

/* Bytes the caller must allocate for one world. Fixed — DW_NUM_LOCATIONS
 * / DW_NUM_DRUGS / DW_MAX_HIGHSCORES are compile-time constants, so this
 * takes no config argument. */
size_t dw_world_size(void);

/* Required alignment for the storage passed to dw_world_init. */
size_t dw_world_align(void);

/* Initializes caller-supplied storage (dw_world_size() bytes, aligned to
 * dw_world_align()) as a fresh game (`index.html:686-709`'s newGame):
 * seeds the RNG stream from config->rng_seed, zeroes the inventory,
 * applies num_days / start_cash overrides (or the ruleset defaults when
 * fields carry their "use default" sentinels), sets the player at
 * bronx with the default coat/health/debt, and calls generate_prices
 * once for day 1 (drawing from the RNG stream this call just seeded).
 *
 * Returns DW_ERR_ABI_VERSION_MISMATCH if config->abi_version !=
 * DW_ABI_VERSION, DW_ERR_INVALID_ARGUMENT if world or config is NULL. */
dw_result dw_world_init(dw_world *world, const dw_config *config);

/* Resets an already-initialized world to a fresh game, reusing the same
 * config the previous dw_world_init was given (which is retained inside
 * the handle's storage). The RNG is reseeded from that config's
 * rng_seed — this is a full "new game", not a mid-game reset. */
dw_result dw_world_reset(dw_world *world);

/* ---------------------------------------------------------------------- */
/* Live-state queries                                                      */
/* ---------------------------------------------------------------------- */

/* Snapshot the scalar state fields into *out_view. */
dw_result dw_state_get(const dw_world *world, dw_state_view *out_view);

/* Denormalized coat-space accounting, matching `index.html:711-716`.
 * Also available via dw_state_view.coat_used. */
dw_result dw_coat_used(const dw_world *world, int32_t *out_used);

/* Two-call length-then-fill; required length is the count of drugs
 * traded at the current location this turn (0..DW_NUM_DRUGS). */
dw_result dw_prices_copy(const dw_world *world, dw_price_slot *out_prices, size_t out_capacity, size_t *out_required);

/* Two-call length-then-fill; required length is the count of drugs
 * currently held with qty > 0. */
dw_result dw_inventory_copy(const dw_world *world, dw_inventory_slot *out_inventory, size_t out_capacity, size_t *out_required);

/* Two-call length-then-fill over the *previous* turn's price table, so a
 * caller can render a per-drug price delta. The drug set traded last turn
 * need not match this turn's, so callers intersect the two copies rather
 * than assuming the orders line up. On day 1 nothing has been traded yet
 * and the required length is 0. */
dw_result dw_prev_prices_copy(const dw_world *world, dw_price_slot *out_prices, size_t out_capacity, size_t *out_required);

/* Look up a drug or location by id (NUL-terminated UTF-8, must match one
 * of the ruleset entries). Returns DW_ERR_UNKNOWN_DRUG /
 * DW_ERR_UNKNOWN_LOCATION on miss; *out_index unchanged in that case. */
dw_result dw_find_drug_index(const char *id, uint32_t *out_index);
dw_result dw_find_location_index(const char *id, uint32_t *out_index);

/* ---------------------------------------------------------------------- */
/* Turn actions                                                            */
/* ---------------------------------------------------------------------- */

/* Regenerates the current location's price table (`index.html:718-762`),
 * drawing from the world's RNG stream. Any cheap/expensive events
 * produced are queued for dw_price_events_drain; the previous turn's
 * events are dropped by this call.
 *
 * Called automatically by dw_world_init (for day 1) and dw_travel;
 * consumers normally do not call this directly. Exposed because the JS
 * oracle exposes generatePrices and TASK-001.02's parity fixtures need
 * to invoke identical draw sequences. */
dw_result dw_generate_prices(dw_world *world);

/* Two-call length-then-fill for the price events produced by the most
 * recent dw_generate_prices call (which is what dw_world_init and
 * dw_travel invoke internally). Draining does not clear the queue —
 * subsequent calls return the same set until the next dw_generate_prices
 * runs. Required length is 0..3 (see `index.html:722-732` for the 70% /
 * 40% / 5% roll table). */
dw_result dw_price_events_drain(const dw_world *world, dw_price_event *out_events, size_t out_capacity, size_t *out_required);

/* Buy `qty` units of `drug_index` at the current location's price for
 * that drug. Returns DW_ERR_UNKNOWN_DRUG, DW_ERR_NOT_TRADED_HERE,
 * DW_ERR_INSUFFICIENT_CASH, DW_ERR_INSUFFICIENT_SPACE, or
 * DW_ERR_INVALID_ARGUMENT (qty == 0) as appropriate; on failure, world
 * state is unchanged. */
dw_result dw_buy(dw_world *world, uint32_t drug_index, uint32_t qty);

/* Sell `qty` units of `drug_index` at the current location's price.
 * Returns DW_ERR_UNKNOWN_DRUG, DW_ERR_NOT_TRADED_HERE,
 * DW_ERR_INSUFFICIENT_INVENTORY, or DW_ERR_INVALID_ARGUMENT (qty == 0)
 * as appropriate; on failure, world state is unchanged. */
dw_result dw_sell(dw_world *world, uint32_t drug_index, uint32_t qty);

/* Travel to `dest_location_index` (`index.html:802-814`): advances the
 * day counter, applies debt/bank compound interest, moves the player,
 * and calls dw_generate_prices for the new day. Returns
 * DW_ERR_UNKNOWN_LOCATION if the index is out of range, DW_ERR_GAME_OVER
 * on the last day, DW_ERR_DEAD if the player is dead, or
 * DW_ERR_INVALID_ARGUMENT if dest equals the current location. */
dw_result dw_travel(dw_world *world, uint32_t dest_location_index);

/* Bank/loan action (`index.html:816-834`). `amount` is truncated to the
 * available cash/bank/debt on the applicable side; *out_actual receives
 * the amount actually moved. Never returns
 * DW_ERR_INSUFFICIENT_* — insufficient balance clamps to zero and
 * succeeds with *out_actual == 0. Returns DW_ERR_INVALID_ARGUMENT for an
 * unknown action. */
dw_result dw_finances(dw_world *world, dw_finances_action action, int64_t amount, int64_t *out_actual);

/* ---------------------------------------------------------------------- */
/* Arrival / dealer events                                                 */
/* ---------------------------------------------------------------------- */

/* Roll one arrival event on entering the new location
 * (`index.html:869-927`). Populates *out_event; kind == DW_ARRIVAL_NONE
 * means nothing happened. State mutations (mugging cash loss, free-drug
 * inventory grant, dog-chase inventory loss, brownies loss, free-weed
 * death, flavor-food cash loss) are applied before this call returns. */
dw_result dw_roll_arrival_event(dw_world *world, dw_arrival_event *out_event);

/* Roll a coat dealer offer without applying it (`index.html:929-934`).
 * Every roll draws from the world's RNG stream, so calling this twice
 * yields two different offers. */
dw_result dw_roll_coat_dealer_offer(dw_world *world, dw_coat_offer *out_offer);

/* Apply the given coat offer (`index.html:936-948`). Draws from cash
 * first, then from the bank with a bank_purchase_fee_bp surcharge if
 * cash is short. Returns DW_ERR_INSUFFICIENT_CASH /
 * DW_ERR_INSUFFICIENT_BANK if neither path can cover the price; on
 * failure, world state is unchanged. */
dw_result dw_accept_coat_offer(dw_world *world, const dw_coat_offer *offer, dw_purchase_result *out_result);

/* Roll a gun dealer offer without applying it (`index.html:950-954`). */
dw_result dw_roll_gun_dealer_offer(dw_world *world, dw_gun_offer *out_offer);

/* Apply the given gun offer (`index.html:956-969`). Same cash-then-bank
 * fallback as dw_accept_coat_offer. Additionally returns
 * DW_ERR_INSUFFICIENT_SPACE if the gun does not fit in the coat. */
dw_result dw_accept_gun_offer(dw_world *world, const dw_gun_offer *offer, dw_purchase_result *out_result);

/* Roll whether each dealer visits on arrival (`index.html:1387-1388`).
 * One call covers both, in the order the turn produces them: the coat
 * draw happens first and the gun draw second, unconditionally, so a caller
 * that reports both can never desynchronize the world's RNG stream by
 * skipping one. A dealer only actually shows up when the player is alive,
 * so each output is 0 when the player is dead -- but the draw is still
 * consumed, matching the JS `state.rng() < 0.15 && !state.dead` order of
 * evaluation. Not called by dw_travel; the caller decides arrival
 * sequencing, since whether the dealers show up at all depends on whether
 * dw_should_start_chase fired first. */
dw_result dw_roll_dealer_visits(dw_world *world, uint8_t *out_coat_visit, uint8_t *out_gun_visit);

/* ---------------------------------------------------------------------- */
/* Chase / combat                                                          */
/* ---------------------------------------------------------------------- */

/* Roll whether a cop chase starts on arrival at the new location, per
 * `index.html:971-975`. */
dw_result dw_should_start_chase(dw_world *world, uint8_t *out_should_start);

/* Populate *out_chase for a chase that dw_should_start_chase just
 * approved (`index.html:977-985`). Deputy count is a function of the
 * current day. Does not draw from the RNG stream. */
dw_result dw_start_chase(const dw_world *world, dw_chase *out_chase);

/* Snapshot the player's attack/defend ratings for a live chase
 * (`index.html:987-993`). Does not draw from the RNG stream. */
dw_result dw_get_fight_ratings(const dw_world *world, dw_fight_ratings *out_ratings);

/* Attempt to run from an active chase (`index.html:995-1003`).
 * `is_aggressor` = 1 when the player has been trading blows this chase
 * (which lowers the escape chance to 30%). Applies damage on a failed
 * run before returning. */
dw_result dw_run_from_chase(dw_world *world, dw_chase *chase, uint8_t is_aggressor, dw_run_result *out_result);

/* Exchange one round of fire with the chase (`index.html:1005-1019`).
 * On a hit, one deputy falls (chase->deputies is decremented in place).
 * On a miss, the player takes damage. `won` in the result is set when
 * chase->deputies has reached zero on this exchange. */
dw_result dw_fight(dw_world *world, dw_chase *chase, dw_fight_result *out_result);

/* Apply arbitrary damage to the player (`index.html:861-865`). Used by
 * event flows that inflict damage outside a chase; also called
 * internally by dw_roll_arrival_event / dw_run_from_chase / dw_fight
 * so consumers rarely invoke it directly. `*out_health` receives the
 * clamped post-damage health value. */
dw_result dw_apply_damage(dw_world *world, int32_t amount, int32_t *out_health);

/* ---------------------------------------------------------------------- */
/* Endgame                                                                 */
/* ---------------------------------------------------------------------- */

/* Compute the endgame score (`index.html:1021-1024`). Does not mutate
 * state; a caller may call this at any time to preview the current
 * score. */
dw_result dw_finish(const dw_world *world, dw_finish_result *out_result);

/* Insert `entry` into the high-score table and truncate to
 * DW_MAX_HIGHSCORES. `scores` is caller-owned storage laid out as a
 * dense array; `in_count` is the number of live entries on entry;
 * *out_count receives the new count (<= DW_MAX_HIGHSCORES). The array
 * is sorted in place, highest score first, matching
 * `index.html:1026-1031`. Requires scores_capacity >= DW_MAX_HIGHSCORES;
 * violation returns DW_ERR_BUFFER_TOO_SMALL. */
dw_result dw_insert_highscore(dw_highscore_entry *scores, size_t scores_capacity, size_t in_count, const dw_highscore_entry *entry, size_t *out_count);

/* ---------------------------------------------------------------------- */
/* Canonical serialization                                                 */
/* ---------------------------------------------------------------------- */

/* Exact byte length dw_world_dump will write. Fixed for a given
 * DW_ABI_VERSION — does not depend on inventory occupancy or price
 * table content, since both are dumped fully with zero-padding. */
size_t dw_world_dump_len(void);

/* Encodes the world's current state as the frozen little-endian byte
 * sequence documented in docs/abi-contract.md. Two-call contract: pass
 * out_buf == NULL to just learn *out_written (always
 * dw_world_dump_len()); otherwise fills out_buf. Returns
 * DW_ERR_BUFFER_TOO_SMALL if out_capacity is smaller than the required
 * length (still setting *out_written). */
dw_result dw_world_dump(const dw_world *world, uint8_t *out_buf, size_t out_capacity, size_t *out_written);

/* Rehydrate a previously dumped world in place. buf/buf_len must be the
 * exact byte sequence dw_world_dump produced at the same
 * DW_ABI_VERSION. Bit-for-bit round-trip is required: dumping the
 * loaded world must yield the input bytes exactly. Returns
 * DW_ERR_SERIALIZATION_FAILED on any inconsistency (wrong length,
 * unknown location/drug id, corrupt scalars); on failure, world state
 * is unchanged. */
dw_result dw_world_load(dw_world *world, const uint8_t *buf, size_t buf_len);

#ifdef __cplusplus
} /* extern "C" */
#endif

#endif /* DOPEWARS_H */
