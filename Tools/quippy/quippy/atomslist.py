class AtomsList(list):
    def __repr__(self):
        return 'AtomsList(%r)' % list.__repr__(self)

    def show(self, property=None, frame=None):
        try:
           import atomeye
           atomeye.show(self,property, frame)
        except ImportError:
           raise RuntimeError('AtomEye not available')

        
class GenericFrameReader(AtomsList):
   """Read-only access to an XYZ or NetCDF trajectory. The file is opened
   and then read lazily as frames are asked for. Supports list-like interface:

   fr = FrameReader('foo.xyz')
   at1 = fr[0]      # First frame
   at2 = fr[-1]     # Last frame
   ats = fr[0:10:3] # Every third frame between 0 and 10
   ats = [ a for a in fr if a.n == 100 ]  # Only frames with exactly 100 atoms
"""
   def __init__(self, source, start=0, stop=-1, step=None, count=None):

      self._init(source)
      if count is not None:
         self.frames = slice(count)
      else:
         self.frames = slice(start,stop,step)

      self._list = [None for a in range(*(self.frames.indices(self._nframe()+1)))]


   def __del__(self):
      self._close()

   def __len__(self):
      return len(range(*self.frames.indices(self._nframe()+1)))

   def __getitem__(self, frame):
      start, stop, step = self.frames.indices(self._nframe()+1)

      if isinstance(frame, int):
         if frame < 0: frame = frame + (stop - start)
         if start + frame >= stop:
            raise ValueError("frame %d out of range %d" % (start + frame, stop))
         if self._list[frame] is None:
            self._list[frame] = self._getframe(start+frame)
         return self._list[frame]

      elif isinstance(frame, slice):
         allframes = range(start, stop, step)
         subframes = [ allframes[i] for i in range(*frame.indices(len(allframes))) ]
         print allframes, subframes
         res = []
         for f in subframes:
            if self._list[f] is None:
               self._list[f] = self_getframe(f)
            res.append(self._list[f])
         return res
      else:
         raise TypeError('frame should be either an integer or a slice')

   def __getslice__(self, first, last):
      return self.__getitem__(slice(first,last,None))

   def __iter__(self):
      for frame in range(*self.frames.indices(self._nframe()+1)):
         yield self[frame]
      raise StopIteration

   def __reversed__(self):
      for frame in reversed(range(*self.frames.indices(self._nframe()+1))):
         yield self[frame]
      raise StopIteration


class CInOutputFrameReader(GenericFrameReader):
   def _init(self, source):
      from quippy import CInOutput
      self.cio = CInOutput(source)
      self.cio.query()

   def _close(self):
      self.cio.close()

   def _getframe(self, frame):
      return self.cio.read(frame) 

   def _nframe(self):
      return self.cio.n_frame
   
FrameReader = CInOutputFrameReader

try:
   from netCDF4 import Dataset

   class NetCDFFrameReader(GenericFrameReader):

      def _init(self, source):
         self.nc = Dataset(source)

      def _close(self):
         self.nc.close()

      def _getframe(self, frame):
         from quippy import Atoms, make_lattice
         from math import pi
         from quippy import (PROPERTY_INT, PROPERTY_REAL, PROPERTY_STR, PROPERTY_LOGICAL,
                             T_NONE, T_INTEGER, T_REAL, T_COMPLEX,
                             T_CHAR, T_LOGICAL, T_INTEGER_A,
                             T_REAL_A, T_COMPLEX_A, T_CHAR_A, T_LOGICAL_A)

         DEG_TO_RAD = pi/180.0

         remap_names = {'coordinates': 'pos',
                        'velocities': 'velo',
                        'cell_lengths': None,
                        'cell_angles': None}
         
         prop_type_to_value = {PROPERTY_INT: 0,
                               PROPERTY_REAL: 0.0,
                               PROPERTY_STR: "",
                               PROPERTY_LOGICAL: False}

         prop_dim_to_ncols = {('frame','atom','spatial'): 3,
                              ('frame','atom','label'): 1,
                              ('frame', 'atom'): 1}


         cl = self.nc.variables['cell_lengths'][frame]
         ca = self.nc.variables['cell_angles'][frame]
         lattice = make_lattice(cl[0],cl[1],cl[2],ca[0]*DEG_TO_RAD,ca[1]*DEG_TO_RAD,ca[2]*DEG_TO_RAD)

         a = Atoms(len(self.nc.dimensions['atom']),lattice)

         for name, var in self.nc.variables.iteritems():
            name = remap_names.get(name, name)

            if name is None:
               continue

            if 'frame' in var.dimensions:
               if 'atom' in var.dimensions:
                  # It's a property
                  a.add_property(name, prop_type_to_value[var.type],
                                 n_cols=prop_dim_to_ncols[var.dimensions])
                  getattr(a,name.lower())[...] = var[frame].T
               else:
                  # It's a param
                  if var.dimensions == ('frame','string'):
                     # if it's a single string, join it and strip it
                     a.params[name] = ''.join(var[frame]).strip()
                  else:
                     a.params[name] = var[frame]
                  
         return a

      def _nframe(self):
         return len(self.nc.dimensions['frame'])

except ImportError:
   print 'netCDF4 module not found - NetCDFFrameReader disabled.'


class Trajectory(object):
    def __init__(self, ds, pot, dt, n_steps, save_interval, connect_interval):
        self.ds = ds
        self.pot = pot
        self.dt = dt
        self.n_steps = n_steps
        self.save_interval = save_interval
        self.connect_interval = connect_interval

        self.f = fzeros((3,ds.atoms.n))
        self.e = farray(0.0)
        self.pot.calc(ds.atoms, f=self.f, e=self.e)

    def __iter__(self):
        for n in range(self.n_steps):
            self.ds.advance_verlet1(self.dt, self.f)
            self.pot.calc(self.ds.atoms, e=self.e, f=self.f)
            self.ds.advance_verlet2(self.dt, self.f)
            self.ds.print_status(epot=self.e)
            if n % self.connect_interval == 0:
                self.ds.atoms.calc_connect()
            if n % self.save_interval == 0:
                yield self.ds.atoms.copy()
        raise StopIteration
