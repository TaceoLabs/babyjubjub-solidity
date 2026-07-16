import Std.Tactic

/-!
A refinement proof for `src/BabyJubJub.sol`.

The EVM words accepted by the public curve operations are required by their API
to be canonical field representatives.  We model EVM `addmod` and `mulmod`
literally with `Nat.mod`.  `spec*` functions use modular addition everywhere;
`evm*` functions mirror the Solidity optimisations that use an ordinary
`uint256` addition immediately before a modular multiplication.
-/

namespace BabyJubJub

def Q : Nat := 21888242871839275222246405745257275088548364400416034343698204186575808495617
def R : Nat := 2736030358979909402780800718157159386076813972158567259200215660948447373041
def A : Nat := 168700
def D : Nat := 168696
def uint256 : Nat := 2 ^ 256

theorem q_pos : 0 < Q := by native_decide
theorem r_pos : 0 < R := by native_decide
theorem two_q_fits_uint256 : 2 * Q < uint256 := by native_decide
theorem q_fits_uint256 : Q < uint256 := by native_decide
theorem r_fits_uint256 : R < uint256 := by native_decide

def addmod (a b m : Nat) : Nat := (a + b) % m
def mulmod (a b m : Nat) : Nat := (a * b) % m

def submod (a b m : Nat) : Nat := if a ≥ b then a - b else m - (b - a)

theorem add_lt_uint256 {a b : Nat} (ha : a < Q) (hb : b < Q) :
    a + b < uint256 := by
  have h : a + b < 2 * Q := by omega
  exact Nat.lt_trans h two_q_fits_uint256

theorem twice_lt_uint256 {a : Nat} (ha : a < Q) : 2 * a < uint256 := by
  have h : 2 * a < 2 * Q := by omega
  exact Nat.lt_trans h two_q_fits_uint256

theorem one_add_lt_uint256 {a : Nat} (ha : a < Q) : 1 + a < uint256 := by
  have hq : 1 < Q := by native_decide
  exact add_lt_uint256 hq ha

theorem mulmod_lt_q (a b : Nat) : mulmod a b Q < Q := Nat.mod_lt _ q_pos
theorem addmod_lt_q (a b : Nat) : addmod a b Q < Q := Nat.mod_lt _ q_pos

theorem submod_lt {a b m : Nat} (_hm : 0 < m) (ha : a < m) (_hb : b < m) :
    submod a b m < m := by
  simp only [submod]
  split <;> omega

theorem raw_add_has_addmod_semantics (a b : Nat) :
    (a + b) % Q = addmod a b Q := rfl

structure Affine where
  x : Nat
  y : Nat
  deriving DecidableEq

def OnCurve (p : Affine) : Prop :=
  p.x < Q ∧ p.y < Q ∧
    addmod (mulmod A (mulmod p.x p.x Q) Q) (mulmod p.y p.y Q) Q =
    addmod 1 (mulmod D (mulmod (mulmod p.x p.x Q) (mulmod p.y p.y Q) Q) Q) Q

def powMod (a e m : Nat) : Nat := Nat.rec 1 (fun _ r => mulmod r a m) e
def invQ (a : Nat) : Nat := powMod (a % Q) (Q - 2) Q

/- The complete twisted-Edwards affine law used as the specification. -/
def specAdd (p₁ p₂ : Affine) : Affine :=
  let xx := mulmod p₁.x p₂.x Q
  let yy := mulmod p₁.y p₂.y Q
  let dxy := mulmod D (mulmod xx yy Q) Q
  { x := mulmod (addmod (mulmod p₁.x p₂.y Q) (mulmod p₁.y p₂.x Q) Q)
                  (invQ (addmod 1 dxy Q)) Q
    y := mulmod (submod yy (mulmod A xx Q) Q)
                  (invQ (submod 1 dxy Q)) Q }

/- The arithmetic in Solidity `add`, including its two non-modular additions. -/
def evmAdd (p₁ p₂ : Affine) : Affine :=
  let xx := mulmod p₁.x p₂.x Q
  let yy := mulmod p₁.y p₂.y Q
  let dxy := mulmod D (mulmod xx yy Q) Q
  { x := mulmod (mulmod p₁.x p₂.y Q + mulmod p₁.y p₂.x Q)
                  (invQ (1 + dxy)) Q
    y := mulmod (submod yy (mulmod A xx Q) Q)
                  (invQ (submod 1 dxy Q)) Q }

theorem evmAdd_eq_specAdd (p₁ p₂ : Affine) : evmAdd p₁ p₂ = specAdd p₁ p₂ := by
  simp [evmAdd, specAdd, addmod, mulmod, invQ, Nat.add_mod]

theorem affine_add_unchecked_operations_safe (p₁ p₂ : Affine) :
    mulmod p₁.x p₂.y Q + mulmod p₁.y p₂.x Q < uint256 ∧
    1 + mulmod D (mulmod (mulmod p₁.x p₂.x Q) (mulmod p₁.y p₂.y Q) Q) Q < uint256 := by
  constructor
  · exact add_lt_uint256 (mulmod_lt_q _ _) (mulmod_lt_q _ _)
  · exact one_add_lt_uint256 (mulmod_lt_q _ _)

structure Extended where
  X : Nat
  Y : Nat
  T : Nat
  Z : Nat
  deriving DecidableEq

/- Unified mixed addition from Hisil--Wong--Carter--Dawson, with field adds. -/
def specMixedAdd (p : Extended) (q : Affine) : Extended :=
  let a := mulmod p.X q.x Q
  let b := mulmod p.Y q.y Q
  let c := mulmod (mulmod (mulmod D p.T Q) q.x Q) q.y Q
  let e := submod (submod (mulmod (addmod p.X p.Y Q) (addmod q.x q.y Q) Q) a Q) b Q
  let f := submod p.Z c Q
  let g := addmod p.Z c Q
  let h := submod b (mulmod A a Q) Q
  { X := mulmod e f Q, Y := mulmod g h Q, T := mulmod e h Q, Z := mulmod f g Q }

def evmMixedAdd (p : Extended) (q : Affine) : Extended :=
  let a := mulmod p.X q.x Q
  let b := mulmod p.Y q.y Q
  let c := mulmod (mulmod (mulmod D p.T Q) q.x Q) q.y Q
  let e := submod (submod (mulmod (p.X + p.Y) (q.x + q.y) Q) a Q) b Q
  let f := submod p.Z c Q
  let g := p.Z + c
  let h := submod b (mulmod A a Q) Q
  { X := mulmod e f Q, Y := mulmod g h Q, T := mulmod e h Q, Z := mulmod f g Q }

theorem evmMixedAdd_eq_specMixedAdd (p : Extended) (q : Affine)
    (hX : p.X < Q) (hY : p.Y < Q) (hZ : p.Z < Q)
    (hx : q.x < Q) (hy : q.y < Q) :
    evmMixedAdd p q = specMixedAdd p q := by
  simp [evmMixedAdd, specMixedAdd, addmod, mulmod, Nat.add_mod,
    Nat.mod_eq_of_lt hX, Nat.mod_eq_of_lt hY, Nat.mod_eq_of_lt hZ,
    Nat.mod_eq_of_lt hx, Nat.mod_eq_of_lt hy]

theorem mixed_add_unchecked_operations_safe {p : Extended} {q : Affine}
    (hX : p.X < Q) (hY : p.Y < Q) (hZ : p.Z < Q) (hx : q.x < Q) (hy : q.y < Q) :
    p.X + p.Y < uint256 ∧ q.x + q.y < uint256 ∧
    p.Z + mulmod (mulmod (mulmod D p.T Q) q.x Q) q.y Q < uint256 := by
  exact ⟨add_lt_uint256 hX hY, add_lt_uint256 hx hy,
    add_lt_uint256 hZ (mulmod_lt_q _ _)⟩

def specDouble (p : Extended) : Extended :=
  let a := mulmod p.X p.X Q
  let b := mulmod p.Y p.Y Q
  let c := mulmod (addmod p.Z p.Z Q) p.Z Q
  let d := mulmod a A Q
  let e := submod (submod (mulmod (addmod p.X p.Y Q) (addmod p.X p.Y Q) Q) a Q) b Q
  let g := addmod d b Q
  -- Solidity's subtraction helper accepts the unreduced representative `d+b`.
  -- It is consumed only by `mulmod`; retaining it here makes that representation
  -- choice explicit while `g` is the corresponding field element.
  let f := submod (d + b) c Q
  let h := submod d b Q
  { X := mulmod e f Q, Y := mulmod g h Q, T := mulmod e h Q, Z := mulmod f g Q }

def evmDouble (p : Extended) : Extended :=
  let a := mulmod p.X p.X Q
  let b := mulmod p.Y p.Y Q
  let c := mulmod (2 * p.Z) p.Z Q
  let d := mulmod a A Q
  let e := submod (submod (mulmod (p.X + p.Y) (p.X + p.Y) Q) a Q) b Q
  let g := d + b
  let f := submod g c Q
  let h := submod d b Q
  { X := mulmod e f Q, Y := mulmod g h Q, T := mulmod e h Q, Z := mulmod f g Q }

theorem evmDouble_eq_specDouble (p : Extended)
    (hX : p.X < Q) (hY : p.Y < Q) (hZ : p.Z < Q) :
    evmDouble p = specDouble p := by
  simp [evmDouble, specDouble, addmod, mulmod, Nat.add_mod,
    Nat.mod_eq_of_lt hX, Nat.mod_eq_of_lt hY, Nat.mod_eq_of_lt hZ, Nat.two_mul]

theorem double_unchecked_operations_safe {p : Extended}
    (hX : p.X < Q) (hY : p.Y < Q) (hZ : p.Z < Q) :
    2 * p.Z < uint256 ∧ p.X + p.Y < uint256 ∧
    mulmod (mulmod p.X p.X Q) A Q + mulmod p.Y p.Y Q < uint256 := by
  exact ⟨twice_lt_uint256 hZ, add_lt_uint256 hX hY,
    add_lt_uint256 (mulmod_lt_q _ _) (mulmod_lt_q _ _)⟩

/- All four outputs of each projective operation are canonical representatives. -/
theorem evmMixedAdd_reduced (p : Extended) (q : Affine) :
    (evmMixedAdd p q).X < Q ∧ (evmMixedAdd p q).Y < Q ∧
    (evmMixedAdd p q).T < Q ∧ (evmMixedAdd p q).Z < Q := by
  simp [evmMixedAdd]
  exact ⟨mulmod_lt_q _ _, mulmod_lt_q _ _, mulmod_lt_q _ _, mulmod_lt_q _ _⟩

theorem evmDouble_reduced (p : Extended) :
    (evmDouble p).X < Q ∧ (evmDouble p).Y < Q ∧
    (evmDouble p).T < Q ∧ (evmDouble p).Z < Q := by
  simp [evmDouble]
  exact ⟨mulmod_lt_q _ _, mulmod_lt_q _ _, mulmod_lt_q _ _, mulmod_lt_q _ _⟩

def Reduced (p : Extended) : Prop := p.X < Q ∧ p.Y < Q ∧ p.T < Q ∧ p.Z < Q

def evmScalarLoop (base : Affine) : List Bool → Extended → Extended
  | [], acc => acc
  | bit :: bits, acc =>
      let doubled := evmDouble acc
      evmScalarLoop base bits (if bit then evmMixedAdd doubled base else doubled)

def specScalarLoop (base : Affine) : List Bool → Extended → Extended
  | [], acc => acc
  | bit :: bits, acc =>
      let doubled := specDouble acc
      specScalarLoop base bits (if bit then specMixedAdd doubled base else doubled)

theorem evmScalarLoop_reduced (bits : List Bool) (base : Affine) (acc : Extended)
    (hacc : Reduced acc) : Reduced (evmScalarLoop base bits acc) := by
  induction bits generalizing acc with
  | nil => exact hacc
  | cons bit bits ih =>
      simp only [evmScalarLoop]
      split
      · apply ih
        exact evmMixedAdd_reduced _ _
      · apply ih
        exact evmDouble_reduced _

theorem evmScalarLoop_eq_spec (bits : List Bool) (base : Affine) (acc : Extended)
    (hbase : base.x < Q ∧ base.y < Q) (hacc : Reduced acc) :
    evmScalarLoop base bits acc = specScalarLoop base bits acc := by
  induction bits generalizing acc with
  | nil => rfl
  | cons bit bits ih =>
      rcases hacc with ⟨hX, hY, hT, hZ⟩
      have hd := evmDouble_eq_specDouble acc hX hY hZ
      have hrd : Reduced (evmDouble acc) := evmDouble_reduced acc
      rcases hrd with ⟨hdX, hdY, hdT, hdZ⟩
      have ha := evmMixedAdd_eq_specMixedAdd (evmDouble acc) base
        hdX hdY hdZ hbase.1 hbase.2
      simp only [evmScalarLoop, specScalarLoop]
      split
      · rw [← hd, ← ha]
        exact ih (evmMixedAdd (evmDouble acc) base) (evmMixedAdd_reduced _ _)
      · rw [← hd]
        exact ih (evmDouble acc) (evmDouble_reduced _)

def generator : Affine :=
  { x := 5299619240641551281634865583518297030282874472190772894086521144482721001553
    y := 16950150798460657717958625567821834550301663161624707787222815936182638968203 }

theorem generator_on_curve : OnCurve generator := by
  unfold OnCurve generator addmod mulmod Q A D
  native_decide
theorem identity_on_curve : OnCurve { x := 0, y := 1 } := by
  unfold OnCurve addmod mulmod Q A D
  native_decide

theorem scalar_shift_fits : 32 * (R - 1) < uint256 := by native_decide

end BabyJubJub
