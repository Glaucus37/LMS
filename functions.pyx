import math
from cython import array
import numpy as np
# cimport numpy as cnp
import random as rand

# from libc.stdlib cimport rand, srand, RAND_MAX

cython: language_level=3

# Variable definitions
cdef int D = 2
cdef int N = 10
cdef double dt = 0.01
cdef double t_max = 0.05
cdef double L = 10.
# cdef double v_init = 5.
cdef double a_init = 5.
cdef double gamma_ = 1.
cdef double kBT = 1.
cdef double m = 1.

cdef double dt_sq = dt ** 2
cdef double o_sqrt_dt = 1 / math.sqrt(dt)
cdef double sigma_ = o_sqrt_dt * math.sqrt(2 * gamma_ * kBT * m)

# cdef int step = 0
cdef int steps_max = int(t_max / dt)
cdef int lat_size = 5
cdef long cells = lat_size ** 2


# Array declarations
print 'Max steps: ', steps_max
cdef double [:, :] x = np.zeros((steps_max, N))
cdef double [:, :] y = np.zeros((steps_max, N))
cdef double [:, :] vx = np.zeros((steps_max, N))
cdef double [:, :] vy = np.zeros((steps_max, N))
cdef double [:, :] ax = np.zeros((steps_max, N))
cdef double [:, :] ay = np.zeros((steps_max, N))
cdef double [:] kin_U = np.zeros(steps_max)
cdef double [:] gauss_vel = np.zeros(2)
# cdef long [:, :] k_neighbors = np.zeros((cells, 5), dtype=np.int32)


cpdef object main(double v_init):
  rand.seed()

  cdef long [:, :] k_neighbors = set_neighbors()

  init_particles(v_init)

  run_sim()

  print 'Average velocity (RMS): ', rms(), '\n'

  for i in range(steps_max):
    print 'step: ', i
    for j in range(N):
      print 'x: ', x[i, j], '\t\ty: ', y[i, j]
      print 'vx: ', vx[i, j], '\tvy: ', vy[i, j]
      print 'ax: ', ax[i, j], '\tay: ', ay[i, j]
    print ''
    print 'kinetic energy: ', kin_U[i]
    print ''

  return vx


# Initialize positions for all particles
cpdef init_particles(double v_init):
  for i in range(N):
    x[0, i] = L * <double>rand.random()
    y[0, i] = L * <double>rand.random()

    vx[0, i] = v_init * <double>rand.random()
    vy[0, i] = v_init * <double>rand.random()

    ax[0, i] = a_init * <double>rand.random()
    ay[0, i] = a_init * <double>rand.random()

  return


# Simulation loop
cdef void run_sim():
  cdef step = 0
  while step < steps_max - 1:
    verlet(step)
    vel_half_step(step)
    accel(step)
    vel_half_step(step)
    kin_U[step] = kin_energy(step)

    step += 1
  kin_U[step] = kin_energy(step)

  return


# Movement
cdef void verlet(int step):
  cdef int next = step + 1
  cdef double x_new
  cdef double y_new
  for i in range(N):
    x_new = x[step, i] + vx[step, i] * dt + 0.5 * ax[step, i] * dt_sq
    y_new = y[step, i] + vy[step, i] * dt + 0.5 * ay[step, i] * dt_sq
    x[next, i] = pbc(x_new)
    y[next, i] = pbc(y_new)

  return


#Update velocity at half steps
cdef void vel_half_step(int step):
  cdef int next = step + 1
  for i in range(N):
    vx[next, i] += 0.5 * ax[step, i] * dt
    vy[next, i] += 0.5 * ay[step, i] * dt

  return


cdef void accel(int step):
  gauss(1.)
  cdef int next = step + 1
  for i in range(N):
    ax[next, i] = -gamma_ * vx[step, i] + sigma_ * gauss_vel[0]
    gauss(1.)
    ay[next, i] = -gamma_ * vy[step, i] + sigma_ * gauss_vel[1]

  return


cdef void gauss(double std_dev):
  cdef double fac, v1, v2
  cdef double r_sq = 0.
  while r_sq > 1. or r_sq == 0.:
    v1 = <double>(2. * rand.random() - 1)
    v2 = <double>(2. * rand.random() - 1)
    r_sq = v1 ** 2 + v2 ** 2
  fac = std_dev * math.sqrt(-2. * math.log(r_sq) / r_sq)
  gauss_vel[0] = v1 * fac
  gauss_vel[1] = v2 * fac

  return


# Periodic boundary conditions
cdef double pbc(double x):
  if x < 0:
    x += L
  elif x >= L:
    x += L

  return x


# calculate rms velocity
cdef double rms():
  cdef double ms = 0
  for i in range(N):
    ms += vx[-1, i] ** 2 + vy[-1, i] ** 2

  return math.sqrt(ms)


cdef double kin_energy(step):
  cdef double kin = 0
  for i in range(N):
    kin += 0.5 * (vx[step, i] ** 2 + vy[step, i] ** 2)

  return kin / N


# Set neighbors for each cell
cdef long [:, :] set_neighbors():
  neighbors = np.zeros((cells, 5), dtype=np.int32)

  for k in range(cells):
    naive_neighbors = np.array([0, 1, lat_size - 1, lat_size, lat_size + 1])
    naive_neighbors += k

    # Boundary conditions on neighbor list
    if k % lat_size == 0:
      naive_neighbors[2] += lat_size
    elif k % lat_size == lat_size - 1:
      naive_neighbors[1] -= lat_size
      naive_neighbors[4] -= lat_size
    if k // lat_size == lat_size - 1:
      naive_neighbors[2] -= cells
      naive_neighbors[3] -= cells
      naive_neighbors[4] -= cells

    neighbors[k] = naive_neighbors

  return neighbors