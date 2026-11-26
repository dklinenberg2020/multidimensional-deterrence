# Multidimensional Deterrence Curves

## Strategic Interaction

Consider two actors, A and B, engaged in a sequential, noncooperative, repeated, negative-sum, full-information game, with full commitment. In the scalar model, each actor conditions the damage it inflicts on its opponent on the damage it suffers. We now allow damage to vary along n dimensions. These might represent different types of damage, such as human, economic, and psychological harm. Let

$$
D^j=(D_1^j,\ldots,D_n^j)^\top\in\mathbb{R}_+^n\tag{1}
$$

denote the vector of damage suffered by actor j. Each side conditions both the magnitude and composition of damage inflicted on the opponent on the vector of damage suffered. The response functions are thus vector-valued:

$$
D^B=R^A(D^A),\qquad D^A=R^B(D^B).\tag{2}
$$

Each component of $R^A$ maps the entire vector of damage suffered by A into damage inflicted on B in a particular dimension. Thus, an actor may respond in a dimension other than that in which it suffered damage. As in the scalar case, we need not specify the underlying welfare functions from which actors derive their response functions.

Starting from damage $D^A$ suffered by A, its response imposes $R^A(D^A)$ on B, and B’s counter-response imposes $R^B(R^A(D^A))$ on A. An equilibrium is a pair of damage vectors $(D^{A*},D^{B*})$ satisfying both response functions in (2).

This note extends the scalar deterrence-curve framework of Berman et al. (2026, Section 2) to an arbitrary finite number of damage dimensions.

## Equilibrium, Escalation, and De-escalation

An equilibrium in the multidimensional model is a pair of damage vectors $(D^{A*},D^{B*})$ satisfying both response functions in (2). Substituting one response function into the other, we can calculate equilibria by solving the system of n nonlinear equations

$$
F(D^{A*})-D^{A*}=0,\qquad F=R^B\circ R^A.\tag{3}
$$

For each nonnegative solution, the corresponding damage suffered by B is $D^{B*}=R^A(D^{A*})$. The system may have no solution, a unique solution, or multiple solutions. In empirical applications we can solve (3) numerically using the estimated response functions, restricting attention to the relevant region of the damage space. Iterating the response functions may recover attracting equilibria but need not recover unstable equilibria.

As in the scalar model, the position and stability of equilibria are properties of the system implied by both response functions. Let $J^j$ denote the Jacobian of actor j’s response function, with elements

$$
J_{k\ell}^j(D^j)=\frac{\partial R_k^j(D^j)}{\partial D_\ell^j}.\tag{4}
$$

Diagonal elements measure marginal responses within dimensions, while off-diagonal elements measure marginal responses across dimensions. We impose no sign restrictions on these elements. An increase in damage suffered in one dimension may induce an increase or a decrease in damage inflicted in any dimension. Moreover, marginal responses may change sign over the damage space. Damage inflicted remains nonnegative. Negative marginal responses might reflect substitution between dimensions, though we need not take a stand on the underlying welfare functions to characterize the resulting dynamics.

**Local stability.** Starting from damage suffered by A in the neighborhood of an interior equilibrium, let $\Delta D_t^A=D_t^A-D^{A*}$, where t indexes successive pairs of actions. A first-order approximation to the dynamics is

$$
\Delta D_{t+1}^A\simeq M\Delta D_t^A,\qquad M=J^B(D^{B*})J^A(D^{A*}).\tag{5}
$$

Let $\lambda_1,\ldots,\lambda_n$ denote the eigenvalues of M. We distinguish four cases. An equilibrium is fully stable (locally asymptotically stable) if all eigenvalues have modulus less than one. It is partially stable (a saddle) if some have modulus less than one and others greater than one, with none on the unit circle. It is fully unstable (repelling) if all have modulus greater than one. Finally, if an eigenvalue has modulus equal to one, linearization alone cannot generally establish the behavior in the corresponding direction. An eigenvalue with modulus greater than one nevertheless implies instability.

Partial stability is a property of the multidimensional model: deviations along stable modes decay while deviations along unstable modes grow. A saddle is unstable in the full damage space. Note that the modes need not correspond to individual dimensions of damage, but may instead involve combinations of dimensions. Thus, stability within each dimension considered separately does not imply stability of the system. Conversely, negative cross-dimensional marginal responses can stabilize interactions that would be unstable in the absence of those responses.

The signs and magnitudes of eigenvalues also characterize the manner in which interactions approach or depart from an equilibrium. Negative real eigenvalues imply alternating deviations along the corresponding modes, while complex eigenvalues imply rotational dynamics. Thus, even when an equilibrium is stable, damage in particular dimensions need not decline monotonically along a de-escalating sequence.

**Complete and incomplete deterrence.** As in the scalar model, complete deterrence occurs at the origin, where neither side suffers damage in any dimension. Incomplete deterrence occurs when at least one side suffers positive damage in at least one dimension. The multidimensional model admits a special case of incomplete deterrence, which we term selective deterrence: damage is zero in some dimensions but positive in others. The dimensions in which deterrence is complete may differ across actors. These distinctions concern the position of an equilibrium rather than its stability. For equilibria on the boundary of the damage space, stability must be assessed with respect to feasible perturbations.

**Global dynamics.** In the scalar model, an unstable equilibrium may bound an interval of damage from which interactions de-escalate toward a stable equilibrium. The analogous object in the multidimensional model is the basin of attraction of an equilibrium: the set of initial damage vectors from which repeated application of F converges to that equilibrium. Its boundary may separate initial conditions that generate convergence from those that generate escalation, or from those that converge to a different equilibrium. Thus, the consequences of damage suffered in one dimension may depend on damage suffered in others, even when response functions are stable over time.

More generally, interactions need not converge to a fixed point. They may generate periodic sequences of damage or other bounded, nonconvergent dynamics. Nor does local stability preclude temporary increases in damage before convergence. These possibilities motivate an empirical distinction between the stability of an estimated equilibrium and the dynamics implied by the estimated response functions away from that equilibrium. We leave restrictions on the shape of response functions sufficient to establish existence, uniqueness, and global convergence to subsequent analysis. The discussion here is deterministic; in the stochastic model, stationary distributions and fixed points of conditional mean response functions need not coincide.

**The scalar model as a special case.** The multidimensional framework nests the scalar deterrence curve model. Consider two actors and restrict damage to a single dimension ($n=1$). The vector-valued response functions reduce to scalar response curves,

$$
D^B=R^A(D^A),\qquad D^A=R^B(D^B).\tag{6}
$$

Their intersection defines an equilibrium, satisfying $D^{A*}=R^B(R^A(D^{A*}))$ and $D^{B*}=R^A(D^{A*})$.

The Jacobian matrices of the respective response functions reduce to their slopes, so that the composite response matrix in (5) has a single eigenvalue, given by the product of those slopes. The condition for local asymptotic stability from linearization becomes

$$
\left|R^{B\prime}(D^{B*})R^{A\prime}(D^{A*})\right|<1.\tag{7}
$$

For upward-sloping response curves, the absolute value is redundant, and we recover precisely the stability condition derived in the scalar model. A product with modulus greater than one implies instability at an interior equilibrium, while a unit-modulus product requires further analysis.

Several properties of multidimensional equilibria have no scalar analogue. In particular, an equilibrium cannot be partially stable, since there is only one mode of adjustment in the composite response process. Nor can actors substitute damage across dimensions or achieve complete deterrence in one dimension while sustaining incomplete deterrence in another.

Under the assumptions illustrated in Figure 1 of the original paper, the basin of attraction of a stable equilibrium reduces to an interval of damage bounded above by an unstable equilibrium. The multidimensional framework thus generalizes the conditions governing escalation and de-escalation while preserving the central result of the scalar model: the stability of deterrence is a property of the interaction of response functions rather than of either response function independently.

For the original scalar stability condition and escalation threshold, see Berman et al. (2026, Section 2B and Figure 1).

## 3. Existence, uniqueness, and stability

Let $K^A,K^B\subseteq\mathbb{R}_+^n$ denote feasible damage spaces, with arbitrary finite n. Write $x=D^A$, $F(x)=R^B(R^A(x))$, $G(x)=x-F(x)$, and $M(x)=J^B(R^A(x))J^A(x)$. An equilibrium solves $G(x^*)=0$, with $D^{B*}=R^A(x^*)$. The following results distinguish existence, uniqueness, and dynamic stability. Proofs are in Appendix B. The first six theorems apply established mathematical results to the deterrence setting.

**Theorem 1 (Existence).** If both damage spaces are nonempty, compact and convex, the responses are continuous, and $R^A(K^A)\subseteq K^B,\ R^B(K^B)\subseteq K^A$, a deterrence equilibrium exists.

This follows from Brouwer’s fixed-point theorem (Border, 1985). No sign restrictions on marginal responses are required.

**Theorem 2 (Local uniqueness).** At an interior equilibrium with continuously differentiable responses in a neighborhood, the equilibrium is locally unique if

$$
\det(I_n-M(x^*))\ne0.\tag{8}
$$

The inverse function theorem (Rudin, 1976) implies that absence of an eigenvalue equal to positive one suffices for isolation. It does not exclude other equilibria elsewhere, nor is it necessary for isolation.

**Theorem 3 (Global uniqueness).** On a rectangular feasible domain, suppose F is continuously differentiable on an open neighborhood and $I_n-M(x)$ is a P-matrix throughout the domain. Then there is at most one equilibrium.

The P-matrix condition requires every principal minor to be positive (Gale and Nikaidô, 1965):

$$
\det[(I_n-M(x))_{SS}]>0,\qquad\varnothing\ne S\subseteq\{1,\ldots,n\}.\tag{10}
$$

Together with Theorem 1 this establishes uniqueness, but not stability.

**Theorem 4 (Local stability).** Suppose F is continuously differentiable near an interior equilibrium.

Let $M^*=M(x^*)$ and let $\lambda_i$ be its eigenvalues, counted with algebraic multiplicity. If $\rho(M^*)<1$, the equilibrium is locally asymptotically stable; if $\rho(M^*)>1$, it is unstable. If $\rho(M^*)=1$, linearization alone does not generally decide stability.

Here the spectral radius is

$$
\rho(M^*)=\max_{1\le i\le n}|\lambda_i|.\tag{11}
$$

The first-order dynamics over pairs of actions are $\Delta x_{t+1}\simeq M^*\Delta x_t$. Define the counts of contracting, expanding and critical modes:

$$
\begin{aligned}n_s&=\#\{i:|\lambda_i|<1\},\\ n_u&=\#\{i:|\lambda_i|>1\},\\ n_c&=\#\{i:|\lambda_i|=1\},\qquad n_s+n_u+n_c=n.\end{aligned}\tag{12}
$$

These count dimensions of real generalized eigenspaces, including both members of complex conjugate pairs (Kuznetsov, 2004).

**Table 1. Local equilibrium types in arbitrary dimension**

| Type | Spectral criterion | Local implication |
|---|---|---|
| Fully stable | $n_s=n$ | All sufficiently small perturbations converge. |
| Partially stable (saddle) | $n_s,n_u>0$, $n_c=0$ | Contracting and expanding modes coexist; unstable overall. |
| Fully unstable (repeller) | $n_u=n$ | Nonzero sufficiently small perturbations eventually leave a local neighborhood. |
| Critical | $n_c>0$, $n_u=0$ | Nonlinear analysis is required. |
| Critical and unstable | $n_c,n_u>0$ | Instability is established; critical modes require further analysis. |

For hyperbolic equilibria ($n_c=0$), there are $n-1$ possible saddle configurations. We propose the stable-mode share

$$
S=n_s/n\tag{13}
$$

as a descriptive measure of the extent of linear contraction, not a measure of overall stability or basin size. Negative real eigenvalues imply alternating deviations; complex eigenvalues imply rotation in real invariant subspaces. Nonnormal matrices can exhibit transient amplification even when all modes ultimately decay (Trefethen and Embree, 2005). Local stability does not imply monotonic de-escalation.

**Theorem 5 (Global convergence).** Suppose $K^A$ is nonempty, closed, convex and invariant under F, which is continuously differentiable on a neighborhood. If for a common induced matrix norm

$$
\sup_{x\in K^A}\|M(x)\|\le c<1,\tag{9}
$$

then the equilibrium is unique on $K^A$, its basin is all of $K^A$, and $\|x_t-x^*\|\le c^t\|x_0-x^*\|$. The result follows from Banach’s contraction theorem (Border, 1985). For the infinity norm, the bound is on maximum absolute row sums. Neither actor need be a contraction individually. Pointwise spectral radii below one do not suffice for this uniform norm criterion.

**Theorem 6 (Stable and unstable manifolds).** At a hyperbolic interior equilibrium of a continuously differentiable map, the local stable manifold has dimension $n_s$. If F is a local diffeomorphism there, the local unstable manifold has dimension $n_u$.

The basin of attraction is

$$
\mathcal B(x^*)=\{x_0\in K^A:\lim_{t\to\infty}F^t(x_0)=x^*\}.\tag{14}
$$

When $n_u=1$, the stable manifold has codimension one and may form part of a basin boundary (Hirsch, Pugh and Shub, 1977; Shub, 1987). This generalizes the scalar escalation threshold. Departure from a local neighborhood need not imply unbounded escalation; trajectories may approach another equilibrium or invariant set. Basin geometry depends on the full response functions.

**Proposition 1 (Cross-dimensional responses).** For $n\ge2$, the isolated-dimension conditions $|J_{ii}^A J_{ii}^B|<1$ for every i are neither necessary nor sufficient for $\rho(J^B J^A)<1$.

Cross-dimensional responses may stabilize or destabilize the joint system. Appendix A illustrates both possibilities; Appendix B proves the general statement. Modes generally involve combinations of damage dimensions rather than individual dimensions.

**Proposition 2 (Equilibrium sensitivity).** If $F(x;\theta)$ is jointly continuously differentiable near a regular interior equilibrium satisfying (8), a locally unique differentiable equilibrium branch exists and obeys

$$
\frac{\partial x^*}{\partial\theta}=(I_n-M^*)^{-1}\frac{\partial F(x^*;\theta)}{\partial\theta}.\tag{15}
$$

An eigenvalue approaching positive one may amplify parameter changes that load on the sensitive mode. Unit-modulus eigenvalues identify potential bifurcations, subject to additional crossing and nondegeneracy conditions (Kuznetsov, 2004).

**Equilibrium damage.** Complete deterrence requires all components of both damage vectors to vanish; selective deterrence requires some but not all to vanish; pervasive incomplete deterrence occurs when all are positive. These classifications concern location, not stability. Boundary equilibria require feasible perturbations; nonsmooth responses may require directional analysis.

**Quadratic responses.** For actor $j$ and output dimension $i$, a general second-order specification is

$$
R_i^j(z)=\alpha_i^j+(\beta_i^j)^\top z+z^\top Q_i^jz,\qquad Q_i^j=(Q_i^j)^\top.\tag{16}
$$

Its gradient is $\beta_i^j+2Q_i^jz$. There are $2n[1+n+n(n+1)/2]$ coefficients across the actors. Coefficients may have either sign, subject to nonnegative predicted damage on the feasible domain. Flooring at zero introduces kinks where ordinary Jacobian tests may not apply. Section 4 illustrates the specification; Appendix A provides two-dimensional criteria.

## 4. A quadratic example

Consider two identical actors and two dimensions of damage. Let $x=D_1^j$ denote human damage (casualties suffered by actor $j$), and $y=D_2^j$ denote physical damage (destruction of infrastructure and physical assets suffered by $j$). Both are measured in normalized damage units. The outputs $R_1$ and $R_2$ denote human and physical damage inflicted on the opposing actor, respectively. Consider the response functions

$$
R_1(x,y)=0.1+0.6x+0.2y-0.1x^2-0.05xy,\tag{17}
$$

$$
R_2(x,y)=0.1+0.2x+0.6y-0.1y^2-0.05xy.\tag{18}
$$

The linear coefficients are positive and the own-dimension quadratic coefficients are negative, implying diminishing marginal retaliation. The negative interaction term implies that damage in either dimension reduces the marginal response to damage in the other. The coefficients are illustrative, not estimates. We restrict attention to $K=[0,2]^2$ for each actor, on which both responses are nonnegative.

At a symmetric equilibrium all four damage levels equal d, so

$$
d=0.1+0.8d-0.15d^2,\qquad d^*=\frac{-0.2+\sqrt{0.1}}{0.3}\approx0.3874.\tag{19}
$$

The other root is negative and therefore inadmissible. The positive root represents incomplete deterrence in both dimensions. The Jacobian of either actor is

$$
J(x,y)=\begin{pmatrix}0.6-0.2x-0.05y&0.2-0.05x\\0.2-0.05y&0.6-0.2y-0.05x\end{pmatrix}.\tag{20}
$$

At the symmetric equilibrium, the composite Jacobian is $M^*=J(d^*,d^*)^2$.

**Stability.** The eigenvectors $(1,1)^\prime$ and $(1,-1)^\prime$ represent changes in aggregate normalized damage and in the composition of damage, respectively. The associated composite eigenvalues are

$$
\lambda_+=(0.8-0.3d^*)^2\approx0.4675,\qquad\lambda_-=(0.4-0.2d^*)^2\approx0.1040.\tag{21}
$$

Both lie strictly inside the unit circle. Thus the equilibrium is locally asymptotically stable. A perturbation that increases human and physical damage together dissipates more slowly, to first order, than a perturbation that redistributes damage between the two dimensions.

**Uniqueness on the feasible damage space.** On $K=[0,2]^2$, all four marginal responses are positive. The minimum response is 0.1 and the maximum is $R_1(2,2)=R_2(2,2)=1.1$. Hence K is invariant under either response function. The maximum absolute row sum of the Jacobian is attained at the origin, giving

$$
\sup_{z\in K}\|J(z)\|_\infty=0.8,\qquad\sup_{z\in K}\|M(z)\|_\infty\le0.64<1.\tag{22}
$$

The contraction mapping theorem therefore establishes that the equilibrium is unique on K (including asymmetric candidates) and globally attracting within K. The entire feasible square belongs to its basin of attraction.

**Implications.** Negative curvature limits retaliation as damage increases, while the interaction term allows the composition of damage to influence marginal responses. In this example marginal responses remain positive throughout the feasible square; negative marginal responses are permitted in the general theory but are not required here. The example does not establish global uniqueness on the unbounded nonnegative orthant, where the polynomial can predict negative damage. Nor does negative curvature alone guarantee stability or uniqueness: these follow here from the particular coefficients and invariant domain. Identical actors are assumed only for analytical tractability.

## Empirical application: Northern Ireland

The empirical objective is to extend the action-level approach of Berman et al. (2026) to a setting in which coercion occurs along several dimensions. We first construct a historical database without imposing an alternating sequence of actions. This separates the measurement of historical activity from the subsequent identification of strategic responses.

**Sources and collection.** Version 0.2 preserves three preliminary tables: monthly reported fatalities (262 observations, January 1972 to October 1993), selected chronology entries (13 observations, 1980–81), and county-level border restrictions (five observations, 1990). The first and third are transcriptions of Irish archival material; the second uses the CAIN chronology. These initial tables have not been independently verified against original scans.

We add 146 source cells, of which 143 contain numerical values, from three documents held by the National Archives of Ireland. The January 1981 Northern Ireland Information Service report provides annual and quarterly counts of house searches and persons charged. The March 1987 Department of Foreign Affairs briefing provides a reported count of housing applicants citing intimidation. The August 1989 Irish Information Partnership compilation reproduces British government annual fatality and injury statistics by victim category for 1969–88.

Selected source pages were visually inspected and manually transcribed. Each new row retains the period, frequency, measure, reported group, value, archive reference, one-based PDF page number, source URL and interpretive notes. Original missing entries remain blank; zeros are retained only when reported. No imputation or reconciliation across sources is performed.

### Measurement and limitations

Human damage is presently measured by realized fatalities and injuries, not expected damage. Victim categories do not establish the identity of the perpetrator. Searches and charges measure security activity rather than damage inflicted on a particular opponent. Border closures are mobility restrictions, not observed economic losses. The 1990 county counts sum to 105 blocked crossings, whereas the accompanying narrative reports 101; this discrepancy remains unresolved.

The annual and quarterly tables provide external validation benchmarks, not individual moves. The selected chronology is not an event census. Neither missing records nor periods without recorded events establish strategic inaction. Before estimating response curves, we require more complete incident-level records, explicit actor attribution, ordering information, duplicate reconciliation and a defensible measure of expected damage. British daily military records have been identified as an acquisition target but are not included in this release.

Archival references. National Archives of Ireland, Northern Ireland Information Service, Statistics on Security, 27 January 1981, DFA/2011/39/1737, PDF pp. 5–6 (the online filename differs from the cover reference). CAIN digital copy.

National Archives of Ireland, Department of Foreign Affairs, Northern Ireland Security Brief, March 1987, DFA/2017/4/6, PDF p. 3. CAIN digital copy.

National Archives of Ireland, Department of the Taoiseach, Irish Information Partnership summary tables, 11 August 1989, TSCH/2019/31/22, PDF p. 4, Table B11. CAIN digital copy.

## Appendix A. The two-dimensional case

For $n=2$, write $M=J^B J^A$, $T=\operatorname{tr} M$, and $\Delta=\det M$. At equilibrium, the characteristic polynomial is $\lambda^2-T\lambda+\Delta$, so

$$
\lambda_{1,2}=\frac{T\pm\sqrt{T^2-4\Delta}}{2}.\tag{A.1}
$$

Writing $a_{ij}$ and $b_{ij}$ for the entries of the respective Jacobians gives

$$
T=a_{11}b_{11}+a_{22}b_{22}+a_{12}b_{21}+a_{21}b_{12},\tag{A.2}
$$

$$
\Delta=(a_{11}a_{22}-a_{12}a_{21})(b_{11}b_{22}-b_{12}b_{21}).\tag{A.3}
$$

The local uniqueness criterion is $1-T+\Delta\ne0$. The global P-matrix condition on a rectangular domain requires, at every feasible x,

$$
1-m_{11}>0,\qquad 1-m_{22}>0,\qquad1-T+\Delta>0.\tag{A.4}
$$

The Jury inequalities for strict linear stability are

$$
1-T+\Delta>0,\qquad1+T+\Delta>0,\qquad1-\Delta>0.\tag{A.5}
$$

These are equivalent to both eigenvalues lying strictly inside the unit circle. They suffice for nonlinear local asymptotic stability at a continuously differentiable interior equilibrium.

For comparative statics, the inverse appearing in Section 3 is

$$
(I_2-M^*)^{-1}=\frac{1}{1-T+\Delta}\begin{pmatrix}1-m_{22}&m_{12}\\m_{21}&1-m_{11}\end{pmatrix},\tag{A.6}
$$

where the entries, trace and determinant are evaluated at equilibrium.

**Classification.** Define $p=1-T+\Delta$ and $q=1+T+\Delta$. The general spectral classification in Section 3 reduces to the following explicit inequalities.

**Table A1. Two-dimensional equilibrium types**

| Type | Eigenvalue criterion | Trace–determinant criterion |
|---|---|---|
| Fully stable | Both moduli below one | $p>0$, $q>0$, $\Delta<1$ |
| Saddle | One below, one above one | $pq<0$ |
| Repeller | Both moduli above one | $\lvert\Delta\rvert>1$, $\Delta p>0$, $\Delta q>0$ |
| Critical | At least one unit modulus | $p=0$ or $q=0$ or $\Delta=1$, $\lvert T\rvert<2$ |

The saddle criterion follows from $pq=(1-\lambda_1^2)(1-\lambda_2^2)$. The repeller criterion follows by applying the Jury inequalities to the inverse matrix, whose trace and determinant are $T/\Delta$ and $1/\Delta$. A critical equilibrium with an additional expanding mode is unstable.

Complex eigenvalues arise when $T^2<4\Delta$ and have modulus $\sqrt{\Delta}$. The boundaries $p=0$, $q=0$, and $\Delta=1$ with $|T|<2$ correspond respectively to eigenvalues $+1$, $-1$, and a complex unit-modulus pair. These identify potential fold, period-doubling, and Neimark–Sacker bifurcations; additional nondegeneracy and parameter-crossing conditions are needed.

**Cross-dimensional stabilization and destabilization.** Consider first identical local Jacobians

$$
J^A=J^B=\begin{pmatrix}0.4&0.8\\0.8&0.4\end{pmatrix}.
$$

The isolated coefficients are both 0.16, whereas the composite eigenvalues are 1.44 and 0.16. The equilibrium is a saddle. Conversely, if

$$
J^A=J^B=\begin{pmatrix}1.2&1.2\\-1.2&-1.1\end{pmatrix},
$$

the isolated coefficients are 1.44 and 1.21, yet the composite eigenvalues both have modulus 0.12. The equilibrium is fully stable. These are illustrative local derivatives, not globally specified damage functions. The examples also extend to higher dimensions by adjoining independent contracting modes to both Jacobians.

**Quadratic specification.** With two input dimensions, the general quadratic response in Section 3 becomes

$$
R_i^j(x,y)=\alpha_i^j+\beta_{i1}^jx+\beta_{i2}^jy+\gamma_{i1}^jx^2+\gamma_{i2}^jy^2+\delta_i^jxy.\tag{A.7}
$$

There are 24 coefficients across two actors and two output dimensions. The marginal responses are $\beta_{i1}^j+2\gamma_{i1}^jx+\delta_i^jy$ and $\beta_{i2}^j+2\gamma_{i2}^jy+\delta_i^jx$. Section 4 gives a concrete specification with positive linear coefficients, negative own-dimension quadratic coefficients, and a negative interaction term.

## Appendix B. Proofs of theorems and propositions

**Proof of Theorem 1.** By continuity and the two inclusion conditions, $F=R^B\circ R^A$ is a continuous self-map of the nonempty compact convex set $K^A$. Brouwer’s theorem gives $x^*\in K^A$ with $F(x^*)=x^*$. Set $y^*=R^A(x^*)\in K^B$. Then $R^B(y^*)=x^*$, so $(x^*,y^*)$ is a deterrence equilibrium. Conversely every deterrence equilibrium gives a fixed point of $F$. $\square$

**Proof of Theorem 2.** By the chain rule, $DG(x)=I_n-M(x)$. At $x^*$ this matrix is nonsingular by (8). The inverse function theorem gives a neighborhood on which $G$ is one-to-one. Since $G(x^*)=0$, no other zero lies in that neighborhood. The correspondence in Theorem 1 transfers isolation to the equilibrium pair. $\square$

**Proof of Theorem 3.** The Gale–Nikaidô theorem states that a continuously differentiable map with a P-matrix Jacobian throughout a rectangle is injective there. Apply it to $G$, whose Jacobian is $I_n-M(x)$. Two distinct equilibria would give two distinct zeros of $G$, contradicting injectivity. For unbounded rectangles, any two candidate points lie in a bounded subrectangle, to which the same argument applies. $\square$

**Proof of Theorem 4.** Translate the fixed point to the origin, so the map is $h\mapsto M^*h+r(h)$, with $\|r(h)\|/\|h\|\to0$. If $\rho(M^*)<1$, there is a vector norm whose induced matrix norm satisfies $\|M^*\|<a<1$ (Horn and Johnson, 2013). For sufficiently small $h$, $\|r(h)\|\le(1-a)\|h\|/2$. Hence the translated map contracts distance to zero by a factor at most $(1+a)/2<1$. Iteration proves local asymptotic stability.

If $\rho(M^*)>1$, the discrete-time linearized instability theorem implies Lyapunov instability (Kuznetsov, 2004). Its hypotheses are met by the continuously differentiable map and an eigenvalue strictly outside the unit circle; invertibility of the entire Jacobian is not required. When all eigenvalues lie outside the unit circle, the inverse function theorem supplies a local inverse with derivative $(M^*)^{-1}$, whose spectral radius is below one. In an adapted norm this inverse contracts locally, so forward iteration expands until leaving a sufficiently small neighborhood. For mixed hyperbolic spectra the stable and unstable subspaces coexist, yielding the saddle classification (Theorem 6).

At unit spectral radius the linearization cannot generally decide stability: the scalar maps $h\mapsto h-h^3$ and $h\mapsto h+h^3$ have the same derivative 1 at zero but respectively attract and repel sufficiently small nonzero perturbations. These examples can be translated to an interior damage point. $\square$

**Proof of Theorem 5.** Convexity ensures that the segment between any $x,z\in K^A$ lies in $K^A$. By the fundamental theorem of calculus,

$$
F(x)-F(z)=\int_0^1M(z+t(x-z))(x-z)\,dt.
$$

Taking the induced norm gives $\|F(x)-F(z)\|\le c\|x-z\|$. The closed set $K^A$ is complete in this norm, and invariance makes $F$ a self-map. Banach’s theorem gives a unique fixed point and convergence from every feasible starting point. Iterating the inequality with $z=x^*$ gives the stated bound and the basin claim. $\square$

**Proof of Theorem 6.** The hyperbolic splitting of $M^*$ decomposes $\mathbb{R}^n$ into real invariant generalized eigenspaces $E^s\oplus E^u$ associated with eigenvalues of modulus below and above one. Their dimensions are $n_s$ and $n_u$. The local stable manifold theorem for maps gives a local invariant manifold tangent to $E^s$ at $x^*$, consisting locally of points that remain near and converge to the fixed point. This stable-manifold conclusion also holds for a noninvertible map. When $F$ is a local diffeomorphism, applying the theorem to the local inverse gives the unstable manifold tangent to $E^u$ (Hirsch, Pugh and Shub, 1977; Shub, 1987). If $n_u=1$, $n_s=n-1$. The codimension statement alone does not establish a global basin boundary. $\square$

**Proof of Proposition 1.** For $n=2$, take identical Jacobians $J^A=J^B=C$ with

$$
C=\begin{pmatrix}.4&.8\\.8&.4\end{pmatrix}.
$$

Both isolated coefficients are $.16<1$, but $C$ has eigenvalues $1.2,-.4$, so $C^2$ has eigenvalues $1.44,.16$. This disproves sufficiency. For necessity, take instead

$$
C=\begin{pmatrix}1.2&1.2\\-1.2&-1.1\end{pmatrix}.
$$

The isolated coefficients are $1.44,1.21>1$. The trace and determinant of $C$ are $.1,.12$; its discriminant is negative. Both eigenvalues have modulus $\sqrt{.12}$, so both eigenvalues of $C^2$ have modulus $.12<1$. For any $n>2$, append the block $.5I_{n-2}$ to each actor’s Jacobian; the extra composite eigenvalues are $.25$, leaving both counterexamples intact. These derivatives are feasible locally: choose a strictly positive equilibrium vector and affine responses with these derivatives in a sufficiently small neighborhood. If globally nonnegative responses are required, a smooth cutoff to the positive constant equilibrium vector outside that neighborhood preserves the derivatives. $\square$

**Proof of Proposition 2.** Define $G(x,\theta)=x-F(x;\theta)$. Its derivative in $x$ at the equilibrium is $I_n-M^*$, nonsingular by (8). The implicit function theorem (Rudin, 1976) gives a locally unique continuously differentiable branch $x^*(\theta)$. Differentiating $G(x^*(\theta),\theta)=0$ yields $(I_n-M^*)\partial_\theta x^*=\partial_\theta F$, and inversion gives (15). The other actor’s equilibrium follows by differentiating $R^A(x^*(\theta);\theta)$. $\square$

## References

Berman, E., P. B. Khadka, D. Klinenberg, and E. F. Klor (2026). Deterrence Through Response Curves: An Empirical Analysis of the Gaza-Israel Conflict. Working paper, July.

Border, K. C. (1985). Fixed Point Theorems with Applications to Economics and Game Theory. Cambridge University Press.

Gale, D., and H. Nikaidô (1965). The Jacobian matrix and global univalence of mappings. Mathematische Annalen, 159, 81–93. doi:10.1007/BF01360282.

Hirsch, M. W., C. C. Pugh, and M. Shub (1977). Invariant Manifolds. Lecture Notes in Mathematics 583. Springer.

Horn, R. A., and C. R. Johnson (2013). Matrix Analysis, 2nd ed. Cambridge University Press.

Kuznetsov, Y. A. (2004). Elements of Applied Bifurcation Theory, 3rd ed. Springer.

Rudin, W. (1976). Principles of Mathematical Analysis, 3rd ed. McGraw-Hill.

Shub, M. (1987). Global Stability of Dynamical Systems. Springer.

Trefethen, L. N., and M. Embree (2005). Spectra and Pseudospectra: The Behavior of Nonnormal Matrices and Operators. Princeton University Press.
