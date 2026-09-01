# Mathematics of the Tate subgroup check

This document derives the mathematics implemented by
`isInCorrectSubgroupAssumingOnCurveTate`. The construction is a specialization
of Koshelev's [Subgroup membership testing on elliptic curves via the Tate
pairing](https://eprint.iacr.org/2022/037.pdf) to Baby Jubjub, whose cofactor is
eight.

## Security precondition

The function is only a subgroup test. It is not a curve-membership test.
Before calling it on an untrusted point, verify that the coordinates are
canonical and that the point satisfies the Baby Jubjub curve equation:

```solidity
require(BabyJubJub.isOnCurve(point));
require(BabyJubJub.isInCorrectSubgroupAssumingOnCurveTate(point));
```

The derivation below assumes this precondition throughout. Without it, the
Tate check can accept an off-curve point, and unreduced coordinates can make
the Solidity arithmetic revert.

## 1. Parameters and notation

Baby Jubjub is the twisted-Edwards curve

$$
    a x_E^2 + y_E^2 = 1 + d x_E^2 y_E^2
$$

over $\mathbb F_Q$, with

$$
\begin{aligned}
Q &= 21888242871839275222246405745257275088548364400416034343698204186575808495617,\\
a &= 168700,\\
d &= 168696.
\end{aligned}
$$

Its group of rational points is cyclic of order

$$
    \#E(\mathbb F_Q)=8R,
$$

where

$$
R = 2736030358979909402780800718157159386076813972158567259200215660948447373041
$$

is prime. If $G$ generates the full group, the desired prime-order subgroup
is

$$
    \mathcal G = \langle [8]G\rangle,
    \qquad \#\mathcal G=R.
$$

The conventional subgroup test is

$$
    P\in\mathcal G \quad\Longleftrightarrow\quad [R]P=\mathcal O.
$$

That test requires a scalar multiplication by the large integer $R$. The
Tate test detects the same condition using the small cofactor eight.

The following notation avoids a collision between the paper and the code:

| Meaning | Paper | Solidity / this document |
| --- | --- | --- |
| Base-field size | $q$ | $Q$ |
| Prime subgroup order | $r$ | $R$ |
| Cofactor | $e$ | $8$ |
| Fixed cofactor-torsion point | $P_0$ | $T$ |
| Point being tested | $Q$ | $P$ |

## 2. The paper's kernel test

For $k\mid Q-1$, the reduced Tate pairing is

$$
t_k : E(\mathbb F_Q)[k]\times E(\mathbb F_Q)/kE(\mathbb F_Q)
      \longrightarrow \mu_k
$$

and can be evaluated as

$$
    t_k(S,P)=f_{k,S}(P)^{(Q-1)/k}.
$$

Here $f_{k,S}$ is a Miller function and $\mu_k$ is the group of
$k$-th roots of unity in $\mathbb F_Q^*$.

For Baby Jubjub, choose

$$
    T=[R]G.
$$

Since $G$ has order $8R$, $T$ has order eight. Also $8\mid Q-1$, so
the reduced 8-Tate pairing is defined over the base field. Define the
character

$$
    h(P)=t_8(T,P).
$$

The full Baby Jubjub group is cyclic, so the second factor $E(\mathbb F_Q)/
8E(\mathbb F_Q)$ has order eight. Non-degeneracy of the Tate pairing makes
$h(G)$ a primitive eighth root of unity. Write

$$
    \zeta=h(G),\qquad \operatorname{ord}(\zeta)=8.
$$

For an arbitrary point $P=[k]G$, bilinearity gives

$$
    h(P)=h([k]G)=h(G)^k=\zeta^k.
$$

It follows that

$$
\begin{aligned}
h(P)=1
&\Longleftrightarrow \zeta^k=1\\
&\Longleftrightarrow k\equiv0\pmod 8\\
&\Longleftrightarrow P\in\langle[8]G\rangle\\
&\Longleftrightarrow P\in\mathcal G.
\end{aligned}
$$

Thus the prime-order subgroup is exactly the kernel of $h$:

$$
    \mathcal G=\ker(P\mapsto t_8(T,P)).
$$

This is Lemma 1 of the paper specialized to a cyclic group and cofactor eight.
Because the group is cyclic, only one Tate character is needed.

## 3. Move from Edwards to Montgomery form

The paper's explicit Miller formulas use a curve of the form

$$
    v^2=u^3+A_Mu^2+u.
$$

Baby Jubjub is birational to the Montgomery curve

$$
    v^2=u^3+168698u^2+u
$$

through

$$
    u=\frac{1+y_E}{1-y_E},
    \qquad
    v=\frac{1+y_E}{(1-y_E)x_E}.
$$

Computing these affine coordinates directly would require a field inversion.
The implementation instead represents the Montgomery point projectively as

$$
    (U:V:W)=((1+y_E)x_E:1+y_E:(1-y_E)x_E).
$$

Whenever the affine map is defined,

$$
    u=\frac UW,
    \qquad
    v=\frac VW.
$$

These coordinates correspond to the Solidity variables as follows:

```solidity
uint256 v = addmod(1, y, Q);                // V
uint256 u = mulmod(v, x, Q);                // U
uint256 w = mulmod(_submod(1, y, Q), x, Q); // W
```

The variable names are lower-case, but mathematically they hold $V,U,W$,
respectively.

The Edwards identity $(0,1)$ is exceptional: the affine birational map has
no image there. The public function therefore accepts the identity before
attempting the map. This is correct because the identity belongs to every
subgroup.

## 4. Miller's function for an order-eight point

Set

$$
    P_0=T,\qquad P_1=[2]T,\qquad P_2=[4]T.
$$

Their orders are eight, four, and two. Write

$$
    P_j=(x_j,y_j)
$$

in affine Montgomery coordinates. For $j=0,1$, let $\lambda_j$ be the
slope of the tangent at $P_j$, and define its tangent line by

$$
    \ell_j(u,v)=(v-y_j)-\lambda_j(u-x_j).
$$

Also define the vertical line through $P_j$ by

$$
    \nu_j(u,v)=u-x_j.
$$

For a doubling step, Miller's recurrence uses a tangent line divided by the
vertical line through the doubled point. For $8=2^3$, the paper packages
the three steps as

$$
\begin{aligned}
\mu_0 &= \frac{\ell_0}{\nu_1},\\
\mu_1 &= \frac{\ell_1}{\nu_2},\\
\mu_2 &= \nu_2,
\end{aligned}
$$

and obtains

$$
    f_{8,T}=\mu_0^4\mu_1^2\mu_2.
$$

The exponents can also be seen directly from the doubling recurrence:

$$
\begin{aligned}
f_{2,T} &= \mu_0,\\
f_{4,T} &= f_{2,T}^2\mu_1=\mu_0^2\mu_1,\\
f_{8,T} &= f_{4,T}^2\mu_2=\mu_0^4\mu_1^2\mu_2.
\end{aligned}
$$

## 5. Specialize the lines to Baby Jubjub

For the fixed point $T$, the implementation uses

$$
\begin{aligned}
x_0 &= \mathtt{TATE\_T\_X},\\
y_0 &= \mathtt{TATE\_T\_Y},\\
\lambda_0 &= \mathtt{TATE\_TANGENT\_0}.
\end{aligned}
$$

The next two multiples have the particularly simple coordinates

$$
    P_1=[2]T=(1,c),
    \qquad
    P_2=[4]T=(0,0),
$$

where

$$
    c=\mathtt{TATE\_TWO\_T\_Y}.
$$

Since $P_1$ lies on the Montgomery curve,

$$
    c^2=1+168698+1=168700.
$$

The tangent slope at $P_1$ is therefore

$$
\begin{aligned}
\lambda_1
&=\frac{3x_1^2+2(168698)x_1+1}{2y_1}\\
&=\frac{3+2(168698)+1}{2c}\\
&=\frac{168700}{c}\\
&=c.
\end{aligned}
$$

Doubling $(1,c)$ then gives $(0,0)$, as required.

### 5.1 The first tangent line

The affine line at $T$ is

$$
\begin{aligned}
\ell_0(u,v)
&=(v-y_0)-\lambda_0(u-x_0)\\
&=v-\lambda_0u+(\lambda_0x_0-y_0).
\end{aligned}
$$

The hard-coded constants satisfy

$$
    \lambda_0x_0-y_0=x_0\pmod Q,
$$

so this simplifies to

$$
    \ell_0(u,v)=v-\lambda_0u+x_0.
$$

In projective coordinates, clear the common denominator $W$ and define

$$
\begin{aligned}
L_0
&=W\ell_0(U/W,V/W)\\
&=V-\lambda_0U+x_0W.
\end{aligned}
$$

This is `line0`:

```solidity
uint256 line0 = addmod(
    _submod(v, mulmod(TATE_TANGENT_0, u, Q), Q),
    mulmod(TATE_T_X, w, Q),
    Q
);
```

Therefore, despite its name,

$$
    \mathtt{line0}=L_0=W\ell_0,
$$

not the affine value $\ell_0$ itself.

### 5.2 The second tangent line

At $P_1=(1,c)$, both the $v$-coordinate and tangent slope equal $c$:

$$
\begin{aligned}
\ell_1(u,v)
&=(v-c)-c(u-1)\\
&=v-cu.
\end{aligned}
$$

Clearing the projective denominator gives

$$
\begin{aligned}
L_1
&=W\ell_1(U/W,V/W)\\
&=V-cU.
\end{aligned}
$$

This is `line1`:

```solidity
uint256 line1 =
    _submod(v, mulmod(TATE_TWO_T_Y, u, Q), Q);
```

Thus

$$
    \mathtt{line1}=L_1=W\ell_1.
$$

## 6. Exact mapping from the lines to the $\mu_j$

The vertical lines simplify because $x_1=1$ and $x_2=0$:

$$
\begin{aligned}
\nu_1
&=u-x_1
=\frac UW-1
=\frac{U-W}{W},\\
\nu_2
&=u-x_2
=\frac UW.
\end{aligned}
$$

Using $\ell_j=L_j/W$, the three $\mu$-terms become

$$
\begin{aligned}
\mu_0
&=\frac{\ell_0}{\nu_1}
=\frac{L_0/W}{(U-W)/W}
=\frac{L_0}{U-W},\\[4pt]
\mu_1
&=\frac{\ell_1}{\nu_2}
=\frac{L_1/W}{U/W}
=\frac{L_1}{U},\\[4pt]
\mu_2
&=\nu_2
=\frac UW.
\end{aligned}
$$

Substitute these expressions into the Miller function:

$$
\begin{aligned}
f_{8,T}(P)
&=\mu_0(P)^4\mu_1(P)^2\mu_2(P)\\
&=\left(\frac{L_0}{U-W}\right)^4
  \left(\frac{L_1}{U}\right)^2
  \left(\frac UW\right)\\
&=\frac{L_0^4L_1^2}{W(U-W)^4U}.
\end{aligned}
$$

Consequently, define

$$
    N=L_0^4L_1^2,
    \qquad
    D=W(U-W)^4U.
$$

Then

$$
    f_{8,T}(P)=\frac ND.
$$

This is exactly the split used by `_tateMillerNumerator` and
`_tateMillerValue`:

```solidity
uint256 line0Squared = mulmod(line0, line0, Q);
uint256 line0Fourth = mulmod(line0Squared, line0Squared, Q);
uint256 numerator = mulmod(
    line0Fourth,
    mulmod(line1, line1, Q),
    Q
); // N = L0^4 * L1^2

uint256 uMinusW = _submod(u, w, Q); // U - W mod Q
uint256 uMinusWSquared = mulmod(uMinusW, uMinusW, Q);
uint256 denominator = mulmod(
    w,
    mulmod(uMinusWSquared, uMinusWSquared, Q),
    Q
);
denominator = mulmod(denominator, u, Q);
// D = W * (U-W)^4 * U
```

The correspondence can be summarized as follows:

| Paper quantity | Projective expression | Solidity |
| --- | --- | --- |
| $\ell_0$ | $L_0/W$ | `line0 / W` |
| $\ell_1$ | $L_1/W$ | `line1 / W` |
| $\nu_1$ | $(U-W)/W$ | vertical line through $[2]T$ |
| $\nu_2$ | $U/W$ | vertical line through $[4]T$ |
| $\mu_0=\ell_0/\nu_1$ | $L_0/(U-W)$ | first Miller step |
| $\mu_1=\ell_1/\nu_2$ | $L_1/U$ | second Miller step |
| $\mu_2=\nu_2$ | $U/W$ | final order-two step |
| $f_{8,T}$ | $N/D$ | represented as `N * D^7` by `_tateMillerValue` |

## 7. Remove the field inversion

The reduced Tate value would normally be computed as

$$
    \left(\frac ND\right)^E,
    \qquad
    E=\frac{Q-1}{8}.
$$

For $D\ne0$, Fermat's theorem gives

$$
    D^{Q-1}=1.
$$

Since $8E=Q-1$,

$$
    7E=(Q-1)-E.
$$

Therefore

$$
\begin{aligned}
(ND^7)^E
&=N^E D^{7E}\\
&=N^E D^{Q-1-E}\\
&=N^E D^{-E}\\
&=\left(\frac ND\right)^E.
\end{aligned}
$$

The implementation can consequently replace the division by multiplication:

$$
    \left(\frac ND\right)^E=(ND^7)^E.
$$

It constructs $D^7=D^4D^2D$:

```solidity
uint256 denominatorSquared = D * D;
uint256 denominatorFourth = denominatorSquared * denominatorSquared;
uint256 denominatorSeventh = denominatorFourth * denominatorSquared * D;
return N * denominatorSeventh;
```

All actual operations use `mulmod(..., Q)`.

Strictly speaking, `_tateMillerValue` returns $ND^7$, not the affine Miller
value $N/D$. They become equivalent only after the final exponentiation.

## 8. Final exponentiation and the Solidity predicate

The fixed exponent is

$$
E=\frac{Q-1}{8}
=2736030358979909402780800718157159386068545550052004292962275523321976061952.
$$

The public predicate is therefore

$$
\begin{aligned}
\mathtt{accept}(P)
&\Longleftrightarrow P=\mathcal O\\
&\quad\lor (ND^7)^{(Q-1)/8}=1\pmod Q\\
&\Longleftrightarrow P=\mathcal O\lor t_8(T,P)=1\\
&\Longleftrightarrow P\in\mathcal G.
\end{aligned}
$$

In Solidity:

```solidity
function isInCorrectSubgroupAssumingOnCurveTate(Affine calldata p)
    public
    view
    returns (bool)
{
    if (isIdentity(p)) return true;

    return _modExpPrecompile(
        _tateMillerValue(p.x, p.y),
        TATE_FINAL_EXPONENT,
        Q
    ) == 1;
}
```

The EVM modular-exponentiation precompile at address `0x05` evaluates the
large exponentiation. This is why the function is `view`, whereas the older
scalar-multiplication check is `pure`.

## 9. Exceptional zero and pole cases

The rational Miller expression $N/D$ is not directly defined when $D=0$.
With the inversion-free representation, $ND^7=0$, so the final result is
zero rather than one and the point is rejected.

Under the documented on-curve precondition, the relevant nonidentity
zero/pole cases are cofactor-torsion points and do not belong to the
prime-order subgroup. The Edwards identity is the sole accepted exceptional
point and is handled before the birational map.

The accompanying Lean development checks all seven concrete nonidentity
8-torsion representatives, including these degenerate cases.

## 10. Relation to the conventional order check

Suppose again that $P=[k]G$. The conventional test gives

$$
\begin{aligned}
[R]P=\mathcal O
&\Longleftrightarrow [Rk]G=\mathcal O\\
&\Longleftrightarrow 8R\mid Rk\\
&\Longleftrightarrow 8\mid k.
\end{aligned}
$$

The Tate test gives

$$
\begin{aligned}
t_8(T,P)=1
&\Longleftrightarrow \zeta^k=1\\
&\Longleftrightarrow 8\mid k.
\end{aligned}
$$

Thus, for canonical on-curve points,

$$
    t_8(T,P)=1
    \quad\Longleftrightarrow\quad
    [R]P=\mathcal O.
$$

The difference is computational: the conventional test performs a large
elliptic-curve scalar multiplication, while the Tate specialization uses a
three-step Miller function followed by one base-field exponentiation handled
by the EVM precompile.

## 11. Proof coverage

`proof/lean/BabyJubJubTateProof.lean` machine-checks the implementation-level
parts of this argument, including:

- the fixed exponent $E=(Q-1)/8$;
- the exact transcription of the Miller arithmetic;
- the `N * D^7` inversion-elimination step;
- the fixed generator's image having exact order eight;
- rejection of all seven nonidentity 8-torsion points;
- the cyclic-group kernel argument; and
- equivalence with the conventional $[R]P=\mathcal O$ test.

The dependency-free proof does not reconstruct general elliptic-curve divisor
theory or prove Tate-pairing bilinearity and non-degeneracy from field axioms.
Those standard pairing facts are made explicit as the `TateEncodingLaws`
hypotheses.

## Reference

Dmitrii Koshelev, [Subgroup membership testing on elliptic curves via the Tate
pairing](https://eprint.iacr.org/2022/037.pdf), IACR ePrint 2022/037.
