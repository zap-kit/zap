# Havok: the constraint solver (hk_2010.2.0-r1, SkyrimSE.exe 1.7.104)

How the jacobians of the ragdolls' and the hanging objects' joints are built and solved. Read in
two layers: the Havok 6.6.0 PC SDK's debug libraries (`hkpConstraintSolver.lib`, `hkpDynamics.lib`,
decompiled with Ghidra; the debug build keeps the function names and the structure), and the same
functions found in the executable by their constants, call shapes and offsets. What is stated
below holds for the executable; 6.6 is named only where 2010.2 differs. Everything is in the
solver's own units (Havok metres, seconds, radians); Skyrim's scale is the caller's.

## Where the code is (1.7.104, base 0x140000000)

| what | address | 6.6 name |
|---|---|---|
| the world's constructor, `setTauAndDamping` inlined in it | 0x140b531c0 | `hkpWorld::hkpWorld(cinfo)`, `hkpSolverInfo::setTauAndDamping` |
| the solver loop (gravity, steps, integration) | 0x140c12e20 | `hkSolveConstraints` |
| the same split per step (the multithreaded jobs) | 0x140c172f0 | `hkSolveConstraintsByTheSteps` |
| one pass over the schemas | 0x140c1ab60 | `hkSolveStepJacobians` (6.6's `hkSolver::solve1d*` are reference copies of its cases) |
| atoms to schemas, a switch on the atom type (jump table 0x140c22828) | 0x140c1f070 | `hkSolverBuildJacobianFromAtomsNotContact` |
| the ball and socket atom | 0x140c22d10 | `buildJacobianFromBallSocketAtom` |
| a 1d linear row with a given rhs (the stiff spring) | 0x140c235f0 | `hk1dLinearBilateralConstraintBuildJacobianWithCustomRhs` |
| a 1d angular bilateral row (the 2d ang atom) | 0x140c23a40 | `hk1dAngularBilateralConstraintBuildJacobian` |
| the angular friction rows | 0x140c23d10 | `hk1dAngularFrictionBuildJacobian` |
| the contact jacobians (not read here) | 0x140c243c0 | |
| the angle approximation | 0x140aabb90 | `hkMath::atan2fApproximation` |
| the hkUFloat8 table, 256 floats | 0x1419ba8c0 | `hkUFloat8_intToReal` |
| schema type to solver-temp count (bytes) | 0x1420c8aa8 | `hkpJacobianSchema::getNumSolverElemTemps` |

The atom types in 2010.2 (the jump table's order): 0 invalid, 1 bridge (calls a function pointer),
2 set local transforms, 3 set local translations, 4 set local rotations, 5 ball socket, 6 stiff
spring, 7 lin, 8 lin soft, 9 lin limit, 10 lin friction, 11 lin motor, 12 2d ang, 13 ang, 14 ang
limit, 15 twist limit, 16 cone limit, 17 ang friction, 18 ang motor, 19 ragdoll motor, 20 pulley,
21 overwrite pivot, 22 contact, **23 setup stabilization (new in 2010)**, 24 and up other new atoms
and the modifiers. The first 22 are 6.6's.

## The solver's numbers

`hkpWorldCinfo` carries tau (+0x88), damping (+0x8c), iterations (+0x90), micro steps (+0x94) and
the max constraint violation (+0x98). The defaults, which Skyrim adopts, are tau 0.6, damping 1.0,
4 iterations, 1 micro step. The `setupSolverInfo` presets are 2, 4 or 8 iterations with (tau,
damping) = (0.3, 0.9) soft, (0.6, 1.0) medium, (0.9, 1.1) hard.

`setTauAndDamping(tau, damping)` stores, in `hkpSolverInfo` (inside the world at +0x2c0):

- `m_tau = tau`, `m_damping = damping`, `m_frictionTau = 0.5 tau`;
- `m_dampDivTau = damping / tau` (D below), `m_tauDivDamp = tau / damping` (f below),
  `m_dampDivFrictionTau = damping / frictionTau`, `m_frictionTauDivDamp = frictionTau / damping`;
- `m_integrateVelocityFactor` = f in all four lanes, `m_invIntegrateVelocityFactor` = D in all four.

With the defaults: frictionTau 0.3, D = 1.6667, f = 0.6.

Per step the world sets (hkpSimulation, before the solve): `m_deltaTime = frameDt / numSteps`,
`m_invDeltaTime = numSteps / frameDt`, `m_invNumSteps`, `m_invNumMicroSteps`,
`globalAccelerationPerSubStep = gravity * m_deltaTime`, `...PerStep = gravity * frameDt`. At 60 Hz
and 4 steps the sub-step is 1/240 s.

The query every builder gets (`hkpConstraintQueryIn::set`; 2010 offsets): +0x00 sub-step dt, +0x04
micro-step dt (sub-step dt over micro steps), +0x08 sub-step 1/dt, +0x0c frame dt, +0x10 frame
1/dt, +0x14 1/numSteps, +0x18 1/(numSteps micro steps), **+0x20 rhsFactor = f * subStepInvDt**,
**+0x24 virtMassFactor = damping**, +0x28 frictionRhsFactor = frictionTauDivDamp * subStepInvDt,
+0x30 accumulator A, +0x38 accumulator B, +0x40 and +0x48 the two world transforms, +0x50 tau,
+0x54 damping, +0x60 maxConstraintViolationSqrd, +0x70 constraint instance, +0x78 runtime (the
atoms' `hkpSolverResults` array, 8 bytes a result: impulse, internal data), +0x80 the
violated-constraints buffer. At the defaults and 1/60 s, rhsFactor = 0.6 * 240 = 144 and
virtMassFactor = 1.

FLT_EPSILON, 1.1920929e-7 (0x34000000), is added to every effective mass before the division, and
is the threshold for "a vector has a length".

## The accumulators

The solver works on `hkpVelocityAccumulator`, 0x80 bytes a body (2010 layout): +0x00 type (0 rigid
body, 1 keyframed, 2 rigid body without gravity), +0x01 context, +0x04 deactivation class, +0x08
gravity factor, +0x10 linear velocity v, +0x20 angular velocity w in the body's **core frame** (its
principal axes), +0x30 inverse inertia diagonal (xyz) and inverse mass (w).

- While the jacobians are built: the centre of mass in the world is at **+0x70**, and coreFromWorld
  is a 3x3 whose columns are stored at +0x40, +0x50, +0x60 (core = M world; a lane of the result
  is the dot of the input with the matching lanes of the three columns). 6.6 kept the centre at
  +0x40 and the columns at +0x50..+0x70.
- While the solver runs: +0x40 holds the linear sum S_lin and +0x50 the angular sum S_ang (zeroed
  at the start). The stabilized ball socket also reads +0x60 as the body's orientation quaternion
  (core to world) and +0x70 as its position.

Every angular jacobian in a schema is in the core frame of its body: the builder rotates a world
axis by coreFromWorld, the solver applies `w += invInertia (lane by lane) * jacobian * impulse`.

## The loop (`hkSolveConstraints`)

1. For every accumulator: S_lin = S_ang = 0. A rigid body (type 0) gets
   `v += gravityFactor * globalAccelerationPerSubStep` once.
2. For step = 0 .. numSteps-1:
   1. `numMicroSteps` passes of `hkSolveStepJacobians` over all schemas, in the order they were
      emitted (Gauss-Seidel: each row sees the effect of the rows before it, in the same pass).
      Inside a constraint the order is the atoms' order; the order of the constraints is the
      solver setup's (not read).
   2. For every accumulator, the integration below.

The integration, per accumulator (u = the real velocity, defined as v - S):

- A velocity with a NaN lane or a lane of 1e7 or more is replaced by zero (v and w both).
- Types 0 and 2 only, with the body's deactivation class row of `hkpSolverInfo::m_deactivationInfo`
  (the table in `game/havokworld.zap`): per lane m = |v| * linearThresholdInv + |w| *
  angularThresholdInv. If all three lanes are below 1: if all are below
  `relativeSleepVelocityThreshold`, v and w become zero, else both are multiplied by
  `slowObjectVelocityMultiplier`.
- d_lin = v - S_lin and d_ang = w - S_ang; then S_lin += f d_lin and S_ang += f d_ang.
- Not the last step: v = S_lin + d_lin + gravityFactor * gravityPerSubStep and w = S_ang + d_ang,
  with the sums as just updated. In u terms: u grows by the gravity only and S gathers f u. (The
  gravity is added numSteps times in all: once before the loop, once after each step but the last.)
- The last step: v = d_lin, w = d_ang (the body keeps u), and the sums are scaled,
  S *= (1 / numSteps) * D. Since f D = 1, S is then the mean of u over the steps.

`hkRigidMotionUtilApplyAccumulators` stores v and the world form of w as the body's velocities and
steps its position with the sum S (clamped to the motion's speed caps), not with v. So a
constraint's position correction moves the body through u and S, while the velocity the body keeps
for the next frame is u alone.

## The schemas and how each is solved

A 1d row (types 5 and 6, 48 bytes, 12 floats): lin axis [0..2], rhs [3], angA [4..6] (A's core
frame), invJacDiag [7], angB [8..10] (B's core frame), maxImpulse [11] (type 6 only). The type byte
is stamped over the low byte of float [0]. Each row also owns one `hkpSolverElemTemp` (the impulse
accumulated this frame, `a`). vA, wA, vB, wB are the accumulators' v and w.

**Bilateral (5), and with an impulse limit (6)**:

    delta = invJacDiag * (rhs - (lin . (vA - vB) + angA . wA + angB . wB))
    type 6 only: delta = clamp(delta, -M - a, M - a)
    vA += invMassA * delta * lin;      vB -= invMassB * delta * lin
    wA += invInertiaA * angA * delta;  wB += invInertiaB * angB * delta
    a += delta

`invJacDiag` is built as `virtMassFactor / (invMassA + invMassB + sum_l invInertiaA_l angA_l^2 +
sum_l invInertiaB_l angB_l^2 + epsilon)`: with damping 1 the exact inverse effective mass, with
damping below 1 a softer row.

**Angular row (0xc, 32 bytes)**: angA [0..2], invDiag [3], angB [4..6], rhs [7]:
`delta = invDiag * (rhs - (angA . wA + angB . wB))`, applied to the angular velocities only; no
clamp.

**Angular limits (0xd, 48 bytes)**: angA [0..2], invDiag [3], angB [4..6], rhs [7], lower [8],
upper [9], tauFactor [10]. SA and SB are the angular sums, D and damping from the solver info:

    p    = tauFactor * rhs
           - (tauFactor * D * (angA . SA + angB . SB)
              + damping * (angA . (wA - SA) + angB . (wB - SB)))
    dMin = (p - lower) * invDiag
    dMax = (p - upper) * invDiag                       (a = the row's accumulated impulse)
    if dMin > -a:      apply dMin     (the lower limit side; a stays positive)
    elif dMax < -a:    apply dMax     (the upper limit side; a stays negative)
    else:              nothing

The delta is applied to w as `invInertia * ang * delta`, and `a += delta`. There is no clamp: the
test alone keeps the accumulated impulse of one sign. This is the one family that uses the sums
and the damping apart: what the earlier steps already moved (D S) is weighed by tauFactor, the
velocity part by damping.

**Angular friction (0xe, 48 bytes)**: angA, invDiag, angB, rhs [7], maxImpulse [8]:
`delta = invDiag * (rhs - (angA . wA + angB . wB))`; if |delta| > maxImpulse, delta is scaled to
magnitude maxImpulse and the scale (the used factor) goes into the row's second temp. So the clamp
is on each iteration's delta, not on the accumulated torque.

**Stabilized ball socket (0x10, 64 bytes; 2010 only)**: see the atom below.

A skipped atom (disabled, or a cone limit whose axes are parallel) emits a 16-byte schema of type
3 that only advances the solver-results pointer. The temps a schema takes (table at 0x1420c8aa8):
1 for types 5, 6, 0xc, 0xd; 2 for 0xe; 3 for 0x10.

## The atoms

### The frames (types 2 and 3)

The set-local-transforms atom (ragdoll, limited hinge, hinge) holds one hkTransform a body, the
pivot in the translation. The builders use, for each body, its world transform composed with that
local transform: the constraint frame's world axes and the world pivot. The set-local-translations
atom (ball and socket, stiff spring) sets only the pivots. Below, A.col[i] is the i-th axis of A's
constraint frame in the world, pA and pB the world pivots, rA = pA - comA, rB = pB - comB.

### Ball and socket, method OLD (`m_solvingMethod` = 1)

Three type 5 rows (type 6 when `m_maxImpulse` is not HK_REAL_MAX, 3.4028e38), one for each world
axis e_k:

- lin = e_k; angA = M_A (rA x e_k); angB = M_B (e_k x rB), M the coreFromWorld;
- invJacDiag as above;
- `rhs_k = rhsFactor * (pB - pA)_k - table[m_velocityStabilizationFactor] * (vRotB - vRotA)_k`,
  where vRotX = (the world angular velocity of X) x rX is the pivot's velocity due to the rotation
  alone, and `table` is the hkUFloat8 table at 0x1419ba8c0 (0, 0.01, 0.02 .. 0.07, then 0.075,
  0.08, 0.085, 0.091 ..; entry 47 is 0.998, 48 is 1.067, 255 is 1000002; three decimals, read the
  256 floats from the executable). 6.6 builds the same rows with its `m_stabilizationFactor`.

Skyrim's skeleton.hkx ragdolls hold exactly this: all 34 ball sockets of the human skeleton and
of the draugr's have `m_solvingMethod` 1, the stabilization byte 48 (factor 1.067), `m_maxImpulse`
HK_REAL_MAX and inertia stabilization 0. So a ragdoll pivot is three bilateral rows with
rhs = 144 * error and the full inverse effective mass at the defaults. (Whether the engine rewrites
the method at run time was not checked.)

If the query's `maxConstraintViolationSqrd` (cinfo 0.05, squared) is under the pivots' squared
distance, the builder appends the constraint instance to the violated buffer (up to 0x80) for the
game's callbacks; the rows are unchanged.

### Ball and socket, method STABILIZED (any other value; 2010 only)

One 64-byte schema of type 0x10 for the three degrees of freedom. The builder stores:
[0..3] maxImpulse squared (maxImpulse itself when it is 1.7e38 or more; only for the breach check,
the solver does not read it), [4..6] the unit vector of rA in A's core frame and [7] its length,
[8..10] and [11] the same for rB, [12] tau * subStepInvDt, [13] the stabilization cap (the setup
stabilization atom's, HK_REAL_MAX when there is none or it is disabled), [14] and [15]
`min(1, invMass_X / (maxInvInertia_X * |r_X| * m_inertiaStabilizationFactor))` for A and B (1 when
the product is under epsilon), maxInvInertia being the largest of the body's three inverse inertia
lanes.

A pass over it:

1. Predict each body at the end of the sub-step from its sums: p' = p + (v + (D-1) S_lin) dt;
   q' = normalize(q advanced by the half vector 0.5 (w + (D-1) S_ang) dt), dt the sub-step.
2. The lever arms then: r'_X = |r_X| * rotate(q'_X, unit_X) (the quaternion rotation 2(w (u x v) +
   u (u . v) + v (w^2 - 1/2))).
3. e = (tau / dt) * ((p'B + r'B) - (p'A + r'A)).
4. K = (invMassA + invMassB) I + sum over A and B of |r_X| f_X J_X^T diag(invInertia_X) J_X, with
   the row k of J_X the unit direction of r'_X crossed with e_k, in the core frame; f_X is [14] or
   [15]. K is inverted with the adjugate and the determinant (reciprocal estimate and one Newton
   step).
5. imp = K^-1 e, scaled to length [13] when longer.
6. Apply: vA += invMassA imp, vB -= invMassB imp; wA += f_A invInertiaA (J_A^T imp),
   wB -= f_B invInertiaB (J_B^T imp). The three temps take the impulse's components.

There is no `rhs - J v` here: the velocities are already in the prediction. The skeletons'
ragdolls do not use it (above); constraints built at run time may (the NIF constraints' path was
not read).

### Setup stabilization (type 23; 2010 only)

`m_enabled` (+2), `m_maxAngle` (+4). Enabled, the stabilized ball socket's cap [13] is
`m_maxAngle * subStepInvDt / max(maxInvInertiaA * |rA|, maxInvInertiaB * |rB|, epsilon)`. The
skeletons hold it disabled with `m_maxAngle` 1.8e19.

### Stiff spring (type 6)

dir = (pA - pB) / |pA - pB|; with a length not above epsilon, dir = (1,0,0) and the length is 0.
One type 5 row: lin = dir. Both bodies' lever arms are taken from the same point, pA (the row
builder is given one point): angA = M_A ((pA - comA) x dir), angB = M_B (dir x (pA - comB)).
`rhs = rhsFactor * (m_length - |pA - pB|)`, invDiag as in the bilateral rows. A pushes along dir
(away from B) when the pivots are closer than the rest length.

### The 2d ang atom (type 12; the limited hinge's and the hinge's axle)

`m_freeRotationAxis` f; i1 = (f+1)%3, i2 = (f+2)%3 (the byte table at 0x141a10170). Two angular
rows (type 0xc) keeping A's axis f aligned with B's:

- row 1: axis = B.col[i2], rhs = -rhsFactor * (A.col[f] . B.col[i1]);
- row 2: axis = -B.col[i1], rhs = -rhsFactor * (A.col[f] . B.col[i2]);

with angA = M_A axis, angB = -M_B axis, invDiag = virtMassFactor / (sum invInertia ang^2 over both
bodies + epsilon).

### The ang limit atom (type 14; the limited hinge's limit)

Disabled: a skip schema. Else one 0xd row: axis = A.col[limitAxis]; with i1 = (limitAxis+1)%3,
i2 = (limitAxis+2)%3, angle = atan2(A.col[i1] . B.col[i2], A.col[i1] . B.col[i1]) (the
approximation in "2010 against 6.6"), then shifted by multiples of 2 pi to within pi of the
previous angle, which is minus the atom's result `internalSolverData`. The row: angA = M_A axis,
angB = -M_B axis, `tauFactor = tau * m_angularLimitsTauFactor`, `invDiag = tauFactor / (sum
invInertia ang^2 + epsilon)`, `rhs = -subStepInvDt * angle`, `lower = -subStepInvDt * minAngle *
tauFactor`, `upper = -subStepInvDt * maxAngle * tauFactor`. Skyrim's hinges: limitAxis 0, tau
factor 1.0, the limits as the file has them (e.g. -1.92 .. 0, -0.596 .. 0.0628).

### The twist limit (type 15)

With the twist axis t: s = A.col[t] + B.col[t], h = s / |s| (B.col[t] and c = 0 when |s| is
under 1e-16), c = 0.5 |s|. With the reference axis r, w = h x B.col[r]: angle = atan2(A.col[r] .
w, A.col[r] . (w x h)), not shifted. The row 0xd: axis h, `tauFactor = tau *
m_angularLimitsTauFactor * c^2` (the limit fades as the two twist axes part), the rest as the ang
limit. The human ragdoll's first joints: twist axis 0, ref axis 1, +-0.1745 rad, tau factor 0.8.

### The cone limit (type 16; a ragdoll has two, the cone and the planes)

a = A.col[twistAxisInA], b = B.col[refAxisInB], x = a x b; with |x|^2 under epsilon, a skip
schema. Else raw = atan2(|x|, a . b), in [0, pi]. Mode 0 (ZERO_WHEN_VECTORS_ALIGNED): angle = raw,
axis = -x / |x|. Mode 1 (ZERO_WHEN_VECTORS_PERPENDICULAR): angle = pi/2 - raw, axis = x / |x|
(the case's sign factor is the float at 0x141a10184 - 4 mode: -1 for mode 0, +1 for mode 1; the angle's
factor and offset are 0x141a10180 + 4 mode and 0x141a10188 + 4 mode, (1, 0) and (-1, pi/2)). The
row 0xd with that axis, `tauFactor = tau * m_angularLimitsTauFactor`, lower and upper the atom's
min and max, rhs = -subStepInvDt * angle.

When `m_memOffsetToAngleOffset` is above 1 (the stabilized cone) the atom keeps a float o in the
constraint runtime at that offset, and the angle is changed before the row is built. With
prev = minus this atom's result `internalSolverData`, a = angle - o, s = max(0.5 frameDt, 0.05 o):

    o' = o - s;   angle' = a + s
    if prev != 0 and a - prev > s + 0.25 frameDt:   o' += a - prev;   angle' = prev + s
    o' = max(o', epsilon)         (stored back to the runtime)

and angle' replaces the angle. It is a ratchet: the offset decays by s every frame, and a jump of
the angle beyond the allowance is fed in slowly (capped at prev + s) while the excess is
remembered in o.

The human ragdoll's atoms: cone: twistAxisInA 0, refAxisInB 0, mode 0, max 0.785 rad (45 deg),
min -100 (never reached), tau factor 0.8, stabilized (offset 56); planes: twistAxisInA 0,
refAxisInB 1, mode 1, per joint (e.g. -0.88 .. 0.26), tau factor 0.8, not stabilized.

### Angular friction (type 17; ragdoll and limited hinge)

Skipped (type 3, `m_numFrictionAxes` results) when disabled or `m_maxFrictionTorque` is 0. Else one
0xe row for each of `m_numFrictionAxes` axes from `m_firstFrictionAxis`, the axis being A.col[i]:
angA = M_A axis, angB = -M_B axis, `invDiag = 1 / (sum invInertia ang^2 + epsilon)` (no
virtMassFactor), `rhs = subStepInvDt * (the row's result internalSolverData from the last frame)`,
`maxImpulse = m_maxFrictionTorque * microStepDt`. Skyrim's ragdoll: 3 axes from 0; the limited
hinge: 1 axis (0); the torque is the joint's.

### Not read

The ragdoll motor (19) and the angular motor (18) atoms and the position motor (Skyrim's dead
ragdolls have them switched off, see NOTES.md). The lin family (7..11), the pulley (20), the chain
constraints (`bhkConstraintChain`: their own solvers, the ball and socket chain and the powered
chain, with their own tau, damping and cfm) and the contact schemas (0x140c243c0). The order in
which a world's constraints are turned into schemas. The runtime path that builds the NIF's
constraints (which solving method, which stabilization factor it sets).

## What the solve leaves for the next frame

Each row's `hkpSolverResults` gets `m_impulseApplied` = the accumulated `a`, and
`m_internalSolverData`, from the 6.6 export (the structure is the same in the executable, not
decoded there): bilateral rows `rhs * D * dt - numSteps dt (J . S)`; the limits
`rhs * dt - numSteps dt (J . S)`, so the next frame's previous angle (minus it) is about the angle;
friction `(rhs * dt - numSteps dt (J . S)) * the used factor`. A type 6 row whose |a| exceeds 0.99
of its maxImpulse is reported as breached.

## 2010.2 against 6.6

- Accumulator: +0x01 context; the build-time centre of mass moved from +0x40 to +0x70 and
  coreFromWorld from +0x50 to +0x40. The solve-time sums are at +0x40 and +0x50 in both.
- `hkpConstraintQueryIn` gains `m_maxConstraintViolationSqrd` and the violated buffer; rhsFactor at
  0x20 and virtMassFactor at 0x24 (6.6, 32-bit: 0x1c, 0x20); 64-bit pointers.
- `hkpSolverInfo` is the same up to +0x128, where `m_maxConstraintViolationSqrd` is added.
- `hkpBallSocketConstraintAtom` is 16 bytes: +2 solving method (0 stabilized, 1 old), +3 bodies to
  notify, +4 velocity stabilization (hkUFloat8), +8 max impulse, +12 inertia stabilization factor.
  The old method is 6.6's with the violation record added; the stabilized method (schema 0x10) and
  the setup stabilization atom (23) are new.
- The ball and socket, hinge, limited hinge and ragdoll data gain an `m_setupStabilization` atom
  (at atoms +48, +144, +144, +144).
- The atom numbering is 6.6's up to 22, the new atom is 23. The row types 5, 6, 0xc, 0xd, 0xe have
  6.6's layouts and formulas (compared case by case in `0x140c1ab60`); 0x10 is new.
- The angle approximation (0x140aabb90): z = min(|x|,|y|) / (max(|x|,|y|) + epsilon);
  p = z - 0.121079 z^2 - 0.0935228 z^3 (the constants 0.12107899785 and 0.09352281690); p = pi/2 - p
  when |y| > |x|; p = pi - p when x < 0; p = -p when y < 0. 6.6 calls a function outside the
  libraries read.

## The layout of Skyrim's ragdoll data (skeleton.hkx, for the port)

`hkpRagdollConstraintData::Atoms` (352 bytes, from +32 of the data): transforms 0, setup
stabilization 144 (type 23, enabled 0, maxAngle 1.8e19), ragdoll motors 160, angular friction 256
(12 bytes), twist 268 (20), cone 288 (20), planes 308 (20), ball socket 328 (16). The limited
hinge's (240 bytes): transforms 0, setup stabilization 144, ang motor 160, ang friction 184, ang
limit 196 (16), 2d ang 212 (4), ball socket 216. Each pass solves them in that order: friction,
then the limits, then the pivot rows.
