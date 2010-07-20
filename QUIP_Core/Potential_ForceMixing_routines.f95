! H0 XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX
! H0 X
! H0 X   libAtoms+QUIP: atomistic simulation library
! H0 X
! H0 X   Portions of this code were written by
! H0 X     Albert Bartok-Partay, Silvia Cereda, Gabor Csanyi, James Kermode,
! H0 X     Ivan Solt, Wojciech Szlachta, Csilla Varnai, Steven Winfield.
! H0 X
! H0 X   Copyright 2006-2010.
! H0 X
! H0 X   These portions of the source code are released under the GNU General
! H0 X   Public License, version 2, http://www.gnu.org/copyleft/gpl.html
! H0 X
! H0 X   If you would like to license the source code under different terms,
! H0 X   please contact Gabor Csanyi, gabor@csanyi.net
! H0 X
! H0 X   Portions of this code were written by Noam Bernstein as part of
! H0 X   his employment for the U.S. Government, and are not subject
! H0 X   to copyright in the USA.
! H0 X
! H0 X
! H0 X   When using this software, please cite the following reference:
! H0 X
! H0 X   http://www.libatoms.org
! H0 X
! H0 X  Additional contributions by
! H0 X    Alessio Comisso, Chiara Gattinoni, and Gianpietro Moras
! H0 X
! H0 XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX

!XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX
!X
!X Force Mixing routines to be included in Potential.f95
!X
!XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX
!XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX


  subroutine Potential_FM_initialise(this, args_str, mmpot, qmpot, reference_bulk, mpi)
    type(Potential_FM), intent(inout) :: this
    character(len=*), intent(in) :: args_str
    type(Potential), intent(inout), target :: qmpot
    type(Potential), optional, intent(inout), target :: mmpot !% if mmpot is not given, a zero potential is assumed, this is most useful in LOTF mode
    type(Atoms), optional, intent(inout) :: reference_bulk
    type(MPI_Context), intent(in), optional :: mpi

    type(Dictionary) :: params
    logical :: minimise_bulk, do_tb_defaults, do_rescale_r
    real(dp) :: dummy_E

    call finalise(this)

    this%init_args_str = args_str

    call initialise(params)
    call param_register(params, 'minimise_mm', 'F', this%minimise_mm)
    call param_register(params, 'calc_weights', 'T', this%calc_weights)
    call param_register(params, 'method', 'conserve_momentum', this%method)
    call param_register(params, 'mm_reweight', '1.0', this%mm_reweight)
    call param_register(params, 'conserve_momentum_weight_method', 'uniform', this%conserve_momentum_weight_method)
    call param_register(params, 'mm_args_str', '', this%mm_args_str)
    call param_register(params, 'qm_args_str', '', this%qm_args_str)
    call param_register(params, 'qm_little_clusters_buffer_hops', '3', this%qm_little_clusters_buffer_hops)
    call param_register(params, 'use_buffer_for_fitting', 'F', this%use_buffer_for_fitting)
    call param_register(params, 'fit_hops', '3', this%fit_hops)
    call param_register(params, 'add_cut_H_in_fitlist', 'F', this%add_cut_H_in_fitlist)
    call param_register(params, 'randomise_buffer', 'F', this%randomise_buffer)
    call param_register(params, 'save_forces', 'T', this%save_forces)
    call param_register(params, 'lotf_spring_hops', '2', this%lotf_spring_hops)
    call param_register(params, 'lotf_interp_order', 'linear', this%lotf_interp_order)
    call param_register(params, 'lotf_interp_space', 'F', this%lotf_interp_space)
    call param_register(params, 'lotf_nneighb_only', 'T', this%lotf_nneighb_only)

    ! Parameters for the MM minimisation
    call param_register(params, 'minim_mm_method', 'cg', this%minim_mm_method)
    call param_register(params, 'minim_mm_tol', '1e-6', this%minim_mm_tol)
    call param_register(params, 'minim_mm_eps_guess', '1e-4', this%minim_mm_eps_guess)
    call param_register(params, 'minim_mm_max_steps', '1000', this%minim_mm_max_steps)
    call param_register(params, 'minim_mm_linminroutine', 'FAST_LINMIN', this%minim_mm_linminroutine)
    call param_register(params, 'minim_mm_do_pos', 'T', this%minim_mm_do_pos)
    call param_register(params, 'minim_mm_do_lat', 'F', this%minim_mm_do_lat)
    call param_register(params, 'minim_mm_do_print', 'F', this%minim_mm_do_print)
    call param_register(params, 'minim_mm_use_n_minim', 'F', this%minim_mm_use_n_minim)
    call param_register(params, 'minim_mm_args_str', '', this%minim_mm_args_str)

    ! Parameters for do_reference_bulk calculation, init time only
    call param_register(params, "minimise_bulk", "F", minimise_bulk)
    call param_register(params, "do_tb_defaults", "F", do_tb_defaults)
    call param_register(params, 'do_rescale_r', 'F', do_rescale_r)

    if (.not. param_read_line(params, args_str, ignore_unknown=.true.,task='Potential_FM_initialise args_str')) then
       call system_abort('Potential_FM_initialise failed to parse args_str="'//trim(args_str)//'"')
    end if

    call finalise(params)

    call initialise(this%create_hybrid_weights_params)
    call read_string(this%create_hybrid_weights_params, args_str)
    call remove_value(this%create_hybrid_weights_params, 'minimise_mm')
    call remove_value(this%create_hybrid_weights_params, 'calc_weights')
    call remove_value(this%create_hybrid_weights_params, 'method')
    call remove_value(this%create_hybrid_weights_params, 'mm_reweight')
    call remove_value(this%create_hybrid_weights_params, 'conserve_momentum_weight_method')
    call remove_value(this%create_hybrid_weights_params, 'mm_args_str')
    call remove_value(this%create_hybrid_weights_params, 'qm_args_str')
    call remove_value(this%create_hybrid_weights_params, 'qm_little_clusters_buffer_hops')
    call remove_value(this%create_hybrid_weights_params, 'use_buffer_for_fitting')
    call remove_value(this%create_hybrid_weights_params, 'fit_hops')
    call remove_value(this%create_hybrid_weights_params, 'add_cut_H_in_fitlist')
    call remove_value(this%create_hybrid_weights_params, 'randomise_buffer')
    call remove_value(this%create_hybrid_weights_params, 'save_forces')
    call remove_value(this%create_hybrid_weights_params, 'lotf_spring_hops')
    call remove_value(this%create_hybrid_weights_params, 'lotf_interp_order')
    call remove_value(this%create_hybrid_weights_params, 'lotf_interp_space')
    call remove_value(this%create_hybrid_weights_params, 'lotf_nneighb_only')
    call remove_value(this%create_hybrid_weights_params, 'do_rescale_r')
    call remove_value(this%create_hybrid_weights_params, 'minim_mm_method')
    call remove_value(this%create_hybrid_weights_params, 'minim_mm_tol')
    call remove_value(this%create_hybrid_weights_params, 'minim_mm_eps_guess')
    call remove_value(this%create_hybrid_weights_params, 'minim_mm_max_steps')
    call remove_value(this%create_hybrid_weights_params, 'minim_mm_linminroutine')
    call remove_value(this%create_hybrid_weights_params, 'minim_mm_do_pos')
    call remove_value(this%create_hybrid_weights_params, 'minim_mm_do_lat')
    call remove_value(this%create_hybrid_weights_params, 'minim_mm_do_print')
    call remove_value(this%create_hybrid_weights_params, 'minim_mm_use_n_minim')
    call remove_value(this%create_hybrid_weights_params, 'minim_mm_args_str')
    call remove_value(this%create_hybrid_weights_params, 'minimise_bulk')
    call remove_value(this%create_hybrid_weights_params, 'do_tb_defaults')

    this%r_scale_pot1 = 1.0_dp
    if (do_rescale_r) then
       if (.not. present(reference_bulk)) &
            call system_abort("potential_forcemixing_initialise got do_rescale_r=T do_tb_defaults="//&
            do_tb_defaults//" but reference_bulk is not present")

       if (.not. present(mmpot)) &
            call system_abort("potential_forcemixing_initialise got do_rescale_r=T but no mmpot was given")

       call do_reference_bulk(reference_bulk, mmpot, qmpot, minimise_bulk, .true., .false., &
            this%r_scale_pot1, dummy_E, do_tb_defaults)
      
       if (this%r_scale_pot1 <= 0.0_dp) this%r_scale_pot1 = 1.0_dp
       call print ("Rescaling positions in region1 potential by " // this%r_scale_pot1 // " to match lattice constants")
    end if

    this%qmpot => qmpot
    if(present(mmpot)) then
       this%mmpot => mmpot
    else
       this%mmpot => null()
    end if

    if (this%minimise_mm .and. present(mmpot)) then
      ! call initialise(this%relax_pot, "Simple", mmpot)
      this%relax_pot => mmpot
    endif

    if (present(mpi)) this%mpi = mpi

  end subroutine Potential_FM_initialise


  subroutine Potential_FM_finalise(this)
    type(Potential_FM), intent(inout) :: this
    
    nullify(this%mmpot)
    nullify(this%qmpot)
    call finalise(this%embedlist)
    call finalise(this%fitlist)

  end subroutine Potential_FM_finalise


  subroutine Potential_FM_print(this, file)
    type(Potential_FM), intent(inout) :: this
    type(Inoutput), intent(inout), optional :: file

    if (current_verbosity() < PRINT_NORMAL) return

    call Print('Potential_FM:',file=file)
    call Print(' minimise_mm='//this%minimise_mm,file=file)
    call Print(' calc_weights='//this%calc_weights,file=file)
    call Print(' method='//trim(this%method),file=file)
    call Print(' mm_reweight='//this%mm_reweight,file=file)
    call Print(' conserve_momentum_weight_method='//this%conserve_momentum_weight_method)
    call Print(' mm_args_str='//trim(this%mm_args_str), file=file)
    call Print(' qm_args_str='//trim(this%qm_args_str), file=file)
    call Print(' qm_little_clusters_buffer_hops='//this%qm_little_clusters_buffer_hops, file=file)
    call print(' use_buffer_for_fitting='//this%use_buffer_for_fitting)
    call Print(' fit_hops='//this%fit_hops, file=file)
    call print(' add_cut_H_in_fitlist='//this%add_cut_H_in_fitlist,file=file)
    call Print(' randomise_buffer='//this%randomise_buffer, file=file)
    call Print(' save_forces='//this%save_forces, file=file)
    call Print(' lotf_spring_hops='//this%lotf_spring_hops, file=file)
    call Print(' lotf_interp_order='//this%lotf_interp_order, file=file)
    call Print(' lotf_interp_space='//this%lotf_interp_space, file=file)
    call Print(' lotf_nneighb_only='//this%lotf_nneighb_only, file=file)
    call Print(' r_scale_pot1='//this%r_scale_pot1, file=file)
    call Print('',file=file)
    call Print(' minim_mm_method='//this%minim_mm_method,file=file)
    call Print(' minim_mm_tol='//this%minim_mm_tol,file=file)
    call Print(' minim_mm_eps_guess='//this%minim_mm_eps_guess,file=file)
    call Print(' minim_mm_max_steps='//this%minim_mm_max_steps,file=file)
    call Print(' minim_mm_linminroutine='//this%minim_mm_linminroutine,file=file)
    call Print(' minim_mm_do_pos='//this%minim_mm_do_pos,file=file)
    call Print(' minim_mm_do_lat='//this%minim_mm_do_lat,file=file)
    call Print(' minim_mm_do_print='//this%minim_mm_do_print,file=file)
    call Print(' minim_mm_use_n_minim='//this%minim_mm_use_n_minim,file=file)
    call Print(' minim_mm_args_str='//trim(this%minim_mm_args_str),file=file)
    call Print('',file=file)
    call Print(' create_hybrid_weights_params '//write_string(this%create_hybrid_weights_params), file=file)
    call Print('',file=file)
    if (associated(this%mmpot)) then
       call Print('MM Potential:',file=file)
       call Print(this%mmpot,file=file)
       call Print('',file=file)
    else
       call print('MM potential not initialised')
    end if
    if (associated(this%qmpot)) then
       call Print('QM potential:',file=file)
       call Print(this%qmpot,file=file)
    else
       call print('QM potential not initialised')
    end if
    call Print('',file=file)

  end subroutine Potential_FM_print


  subroutine Potential_FM_calc(this, at, e, local_e, f, virial, args_str, err)
    type(Potential_FM), intent(inout) :: this
    type(Atoms), intent(inout) :: at
    real(dp), intent(out), optional :: e
    real(dp), intent(out), optional :: local_e(:)
    real(dp), intent(out), optional :: f(:,:)
    real(dp), intent(out), optional :: virial(3,3)
    integer, intent(out), optional :: err
    character(*), intent(in), optional :: args_str

    real(dp), allocatable, dimension(:,:) :: df, df_fit
    real(dp), allocatable, dimension(:,:) :: f_mm, f_qm
    real(dp), pointer, dimension(:,:) :: force_ptr
    real(dp), pointer, dimension(:) :: weight_region1, conserve_momentum_weight
    integer, pointer, dimension(:) :: hybrid, hybrid_mark
    integer :: i
    type(Dictionary) :: params, calc_create_hybrid_weights_params
    logical :: dummy
    logical  :: minimise_mm, calc_weights, save_forces, lotf_do_init, &
         lotf_do_map, lotf_do_fit, lotf_do_interp, lotf_do_qm, lotf_interp_space, &
         randomise_buffer, lotf_nneighb_only
    character(FIELD_LENGTH) :: method, mm_args_str, qm_args_str, conserve_momentum_weight_method, &
         AP_method, lotf_interp_order
    real(dp) :: mm_reweight, dV_dt, f_tot(3), w_tot, weight, lotf_interp
    integer :: fit_hops

    integer :: weight_method, qm_little_clusters_buffer_hops, lotf_spring_hops
    integer,      parameter   :: UNIFORM_WEIGHT=1, MASS_WEIGHT=2, MASS2_WEIGHT=3, USER_WEIGHT=4, CM_WEIGHT_REGION1=5
    integer, allocatable, dimension(:) :: embed, fit
    !NB workaround for pgf90 bug (as of 9.0-1)
    real(dp) :: t_norm
    !NB end of workaround for pgf90 bug (as of 9.0-1)

    if (present(err)) err = 0

    ! Override parameters with those given in args_str
    call initialise(params)
    call param_register(params, "minimise_mm", ''//this%minimise_mm, minimise_mm)
    call param_register(params, "calc_weights", ''//this%calc_weights, calc_weights)
    call param_register(params, "method", this%method, method)
    call param_register(params, "mm_reweight", ''//this%mm_reweight, mm_reweight)
    call param_register(params, 'conserve_momentum_weight_method', ''//this%conserve_momentum_weight_method, &
         conserve_momentum_weight_method)
    call param_register(params, 'mm_args_str', this%mm_args_str, mm_args_str)
    call param_register(params, 'qm_args_str', this%qm_args_str, qm_args_str)
    call param_register(params, 'qm_little_clusters_buffer_hops', ''//this%qm_little_clusters_buffer_hops, qm_little_clusters_buffer_hops)
    call param_register(params, 'use_buffer_for_fitting', ''//this%use_buffer_for_fitting, this%use_buffer_for_fitting)
    call param_register(params, 'fit_hops', ''//this%fit_hops, fit_hops)
    call param_register(params, 'add_cut_H_in_fitlist', ''//this%add_cut_H_in_fitlist,this%add_cut_H_in_fitlist)
    call param_register(params, 'randomise_buffer', ''//this%randomise_buffer, randomise_buffer)
    call param_register(params, 'save_forces', ''//this%save_forces, save_forces)
    call param_register(params, 'lotf_spring_hops', ''//this%lotf_spring_hops, lotf_spring_hops)
    call param_register(params, 'lotf_interp_order', this%lotf_interp_order, lotf_interp_order)
    call param_register(params, 'lotf_interp_space', ''//this%lotf_interp_space, lotf_interp_space)
    call param_register(params, 'lotf_nneighb_only', ''//this%lotf_nneighb_only, lotf_nneighb_only)

    ! override args_str parameters for the MM minimisation
    call param_register(params, 'minim_mm_method', 'cg', this%minim_mm_method)
    call param_register(params, 'minim_mm_tol', '1e-6', this%minim_mm_tol)
    call param_register(params, 'minim_mm_eps_guess', '1e-4', this%minim_mm_eps_guess)
    call param_register(params, 'minim_mm_max_steps', '1000', this%minim_mm_max_steps)
    call param_register(params, 'minim_mm_linminroutine', 'FAST_LINMIN', this%minim_mm_linminroutine)
    call param_register(params, 'minim_mm_do_pos', 'T', this%minim_mm_do_pos)
    call param_register(params, 'minim_mm_do_lat', 'F', this%minim_mm_do_lat)
    call param_register(params, 'minim_mm_do_print', 'F', this%minim_mm_do_print)
    call param_register(params, 'minim_mm_use_n_minim', 'F', this%minim_mm_use_n_minim)
    call param_register(params, 'minim_mm_args_str', '', this%minim_mm_args_str)

    ! lotf parameters, calc time only
    call param_register(params, 'lotf_do_init', 'T', lotf_do_init)
    call param_register(params, 'lotf_do_map', 'F', lotf_do_map)
    call param_register(params, 'lotf_do_qm', 'T', lotf_do_qm)
    call param_register(params, 'lotf_do_fit', 'T', lotf_do_fit)
    call param_register(params, 'lotf_do_interp', 'F', lotf_do_interp)
    call param_register(params, 'lotf_interp', '0.0', lotf_interp)

    if (.not. param_read_line(params, args_str, ignore_unknown=.true.,task='Potential_FM_Calc args_str') ) &
      call system_abort("Potential_FM_calc failed to parse args_str='"//trim(args_str)//"'")
    call finalise(params)

    if (current_verbosity().ge.PRINT_NERD) call print(this)

    call initialise(calc_create_hybrid_weights_params)
    call read_string(calc_create_hybrid_weights_params, write_string(this%create_hybrid_weights_params))
    call read_string(calc_create_hybrid_weights_params, args_str, append=.true.)

    call remove_value(calc_create_hybrid_weights_params, 'minimise_mm')
    call remove_value(calc_create_hybrid_weights_params, 'calc_weights')
    call remove_value(calc_create_hybrid_weights_params, 'method')
    call remove_value(calc_create_hybrid_weights_params, 'mm_reweight')
    call remove_value(calc_create_hybrid_weights_params, 'conserve_momentum_weight_method')
    call remove_value(calc_create_hybrid_weights_params, 'mm_args_str')
    call remove_value(calc_create_hybrid_weights_params, 'qm_args_str')
    call remove_value(calc_create_hybrid_weights_params, 'qm_little_clusters_buffer_hops')
    call remove_value(calc_create_hybrid_weights_params, 'use_buffer_for_fitting')
    call remove_value(calc_create_hybrid_weights_params, 'fit_hops')
    call remove_value(calc_create_hybrid_weights_params, 'add_cut_H_in_fitlist')
    call remove_value(calc_create_hybrid_weights_params, 'randomise_buffer')
    call remove_value(calc_create_hybrid_weights_params, 'save_forces')
    call remove_value(calc_create_hybrid_weights_params, 'lotf_spring_hops')
    call remove_value(calc_create_hybrid_weights_params, 'lotf_interp_order')
    call remove_value(calc_create_hybrid_weights_params, 'lotf_interp_space')
    call remove_value(calc_create_hybrid_weights_params, 'lotf_nneighb_only')
    call remove_value(calc_create_hybrid_weights_params, 'minim_mm_method')
    call remove_value(calc_create_hybrid_weights_params, 'minim_mm_tol')
    call remove_value(calc_create_hybrid_weights_params, 'minim_mm_eps_guess')
    call remove_value(calc_create_hybrid_weights_params, 'minim_mm_max_steps')
    call remove_value(calc_create_hybrid_weights_params, 'minim_mm_linminroutine')
    call remove_value(calc_create_hybrid_weights_params, 'minim_mm_do_pos')
    call remove_value(calc_create_hybrid_weights_params, 'minim_mm_do_lat')
    call remove_value(calc_create_hybrid_weights_params, 'minim_mm_do_print')
    call remove_value(calc_create_hybrid_weights_params, 'minim_mm_use_n_minim')
    call remove_value(calc_create_hybrid_weights_params, 'minim_mm_args_str')
    call remove_value(calc_create_hybrid_weights_params, 'lotf_do_init')
    call remove_value(calc_create_hybrid_weights_params, 'lotf_do_map')
    call remove_value(calc_create_hybrid_weights_params, 'lotf_do_qm')
    call remove_value(calc_create_hybrid_weights_params, 'lotf_do_fit')
    call remove_value(calc_create_hybrid_weights_params, 'lotf_do_interp')
    call remove_value(calc_create_hybrid_weights_params, 'lotf_interp')

    ! Apply
    if (trim(method) == 'force_mixing_abrupt') then
       call set_value(calc_create_hybrid_weights_params, 'buffer_hops', 0)
       call set_value(calc_create_hybrid_weights_params, 'transition_hops', 0)
       call set_value(calc_create_hybrid_weights_params, 'weight_interpolation', 'hop_ramp')
    else if (trim(method) == 'force_mixing_smooth') then
       call set_value(calc_create_hybrid_weights_params, 'weight_interpolation', 'hop_ramp')
    else if (trim(method) == 'force_mixing_super_smooth') then
       call set_value(calc_create_hybrid_weights_params, 'weight_interpolation', 'distance_ramp')
    end if

    if (present(e) .or. present(local_e) .or. present(virial) .or. .not. present(f)) &
         call system_abort('Potential_FM_calc: supports only forces, not energy, virial or local_e')

    allocate(f_mm(3,at%N),f_qm(3,at%N))
    f_mm = 0.0_dp
    f_qm = 0.0_dp

    if (calc_weights) then 

       if (.not. has_property(at, 'hybrid_mark')) &
            call add_property(at, 'hybrid_mark', HYBRID_NO_MARK)

       if (.not. assign_pointer(at, "hybrid", hybrid)) &
            call system_abort("Potential_FM_calc: at doesn't have hybrid property and calc_weights was specified")

       if (.not. assign_pointer(at, 'hybrid_mark', hybrid_mark)) &
            call system_abort('Potential_FM_Calc: hybrid_mark property missing')

       if(any((hybrid.ne.HYBRID_ACTIVE_MARK).and.(hybrid.ne.HYBRID_NO_MARK))) call system_abort('Potential_FM_calc: hybrid property must contain only 1 (for QM) and 0 (anywhere else).')
          !update only the active region, the buffer region will be updated in create_hybrid_weights

       ! if we have a hysteretic buffer, set marks to allow previously active atoms to become buffer atoms
       ! if we don't, then this is irrelevant anyway
       ! create_hybrid_weights will then set the buffer marks
       where (hybrid_mark == HYBRID_ACTIVE_MARK) hybrid_mark = HYBRID_BUFFER_MARK
       where (hybrid == HYBRID_ACTIVE_MARK) hybrid_mark = HYBRID_ACTIVE_MARK

       call Print('Potential_FM_calc: got '//count(hybrid /= 0)//' active atoms.', PRINT_VERBOSE)

       if (count(hybrid_mark == HYBRID_ACTIVE_MARK) == 0) &
            call system_abort('Potential_ForceMixing_Calc: zero active atoms and calc_weights was specified')

       call create_hybrid_weights(at, write_string(calc_create_hybrid_weights_params))

       ! reassign pointers
       
       if (.not. assign_pointer(at, "hybrid", hybrid)) &
            call system_abort("Potential_FM_calc: at doesn't have hybrid property and calc_weights was specified")

       if (.not. assign_pointer(at, 'hybrid_mark', hybrid_mark)) &
            call system_abort('Potential_FM_Calc: hybrid_mark property missing')

    end if

    if (.not. assign_pointer(at, 'hybrid_mark', hybrid_mark)) &
         call system_abort('Potential_FM_Calc: hybrid_mark property missing')

    ! Do the MM minimisation, freezing the atoms marked as active
    if (minimise_mm) then
       call do_minimise_mm(this%relax_pot, at, this%minim_mm_method, this%minim_mm_tol, this%minim_mm_max_steps, &
            this%minim_mm_linminroutine, this%minim_mm_do_pos, this%minim_mm_do_lat, this%minim_mm_do_print, &
            this%minim_mm_args_str, this%minim_mm_eps_guess, this%minim_mm_use_n_minim, this%minim_inoutput_movie, &
            this%minim_cinoutput_movie, find(hybrid_mark == HYBRID_ACTIVE_MARK))
    endif

    ! Do the classical calculation
    if(associated(this%mmpot)) then
       call calc(this%mmpot, at, f=f_mm, err=err, args_str=mm_args_str)
    else
       f_mm = 0
    end if

    !Potential calc could have added properties e.g. old_cluster_mark
    if (.not. assign_pointer(at, 'hybrid_mark', hybrid_mark)) &
         call system_abort('Potential_FM_Calc: hybrid_mark property missing')
    if (.not. any(hybrid_mark /= HYBRID_NO_MARK)) then
       f = f_mm
       return
    end if

    call print('Potential_FM_Calc: reweighting classical forces by '//mm_reweight//' in active region', PRINT_VERBOSE)
    do i=1,at%N
       if (hybrid_mark(i) /= HYBRID_ACTIVE_MARK) cycle
       f_mm(:,i) = mm_reweight*f_mm(:,i)
    end do

    !Fitlist construction has been moved to after the cluster carving in case the cluster is used as the fitlist.

    ! Do the expensive QM calculation. For the LOTF methods we only do this if lotf_do_qm is true
    if (method(1:4) /= 'lotf' .or. (method(1:4) == 'lotf' .and. lotf_do_qm)) then

       call initialise(params)
       call read_string(params, qm_args_str)

       !! TODO - possibly want to set more default options in the qm_args_str here
       if (.not. dictionary_has_key(params, 'buffer_hops')) &
 	 call set_value(params, 'buffer_hops', qm_little_clusters_buffer_hops)

       call set_value(params, 'randomise_buffer', randomise_buffer)

       ! it never hurts to rescale r, as long as the default scale is 1.0
       call set_value(params, 'do_rescale_r', .true.)
       call set_value(params, 'r_scale', this%r_scale_pot1)

       qm_args_str = write_string(params)
       call finalise(params)

       ! Do the QM. If qm_args_str contatins 'small_cluster' or 'little_clusters' options
       ! then potential calc() will do cluster carving. 
       ! We pass along our mpi context object to allow little clusters to be split over
       ! nodes.
       call calc(this%qmpot, at, f=f_qm, args_str=qm_args_str, err=err)
    end if

    !Fitlist construction has been moved here.

    ! Make embed and fit lists if we need them
    if (method(1:4) == 'lotf' .or. trim(method) == 'conserve_momentum') then

       if ((method(1:4) == 'lotf' .and. lotf_do_init) .or. trim(method) == 'conserve_momentum') then
          if (this%use_buffer_for_fitting) then
             if (trim(method).ne.'conserve_momentum') &
                call system_abort('use_buffer_for_fitting=T only works for method=conserve_momentum')
             !create lists according to hybrid_mark property, use BUFFER/TRANS/BUFFER_OUTER_LAYER as fitlist
             call create_embed_and_fit_lists_from_cluster_mark(at,this%embedlist,this%fitlist)
!             if (this%add_cut_H_in_fitlist) then !no cut H on the fitlist's border
!                  call add_cut_hydrogens(at,this%fitlist)
!             endif
          else
             call create_embed_and_fit_lists(at, fit_hops, this%embedlist, this%fitlist, &
                  nneighb_only=lotf_nneighb_only, min_images_only=.true.)
             if (this%add_cut_H_in_fitlist) then !no cut H on the fitlist's border
                  call add_cut_hydrogens(at,this%fitlist)
             endif
          end if

       endif

       ! Make some convenient arrays of embed and fit list
       allocate(embed(this%embedlist%N))
       embed = int_part(this%embedlist,1)
       allocate(fit(this%fitlist%N))
       fit = int_part(this%fitlist,1)
    end if

    if (method(1:4) == 'lotf') then
       
       if (trim(method) == 'lotf_adj_pot_svd' .or. trim(method) == 'lotf_adj_pot_minim') then

          if (trim(method) == 'lotf_adj_pot_svd') then
             AP_method = 'SVD'
          else
             AP_method = 'minim'
          end if
          
          ! Optimise the adjustable potential
          allocate(df(3,this%fitlist%N))
          df = 0.0_dp
          df(:,1:this%embedlist%N) = f_qm(:,embed) - f_mm(:,embed)
    
          if (lotf_do_init) then
             call print('Initialising adjustable potential with map='//lotf_do_map, PRINT_VERBOSE)
             call adjustable_potential_init(at, this%fitlist, directionN=this%embedlist%N, &
                  method=AP_method, nnonly=lotf_nneighb_only, &
                  spring_hops=lotf_spring_hops, map=lotf_do_map)
          end if
            
          if (lotf_do_qm .and. lotf_do_fit) &
               call adjustable_potential_optimise(at, df, method=AP_method)

          if (lotf_do_interp) then
             call adjustable_potential_force(at, df, interp=lotf_interp, &
                  interp_space=lotf_interp_space, interp_order=lotf_interp_order,power=dV_dt)
          else
             call adjustable_potential_force(at, df, power=dV_dt)
          end if
       
          f = f_mm                   ! Start with classical forces
          f(:,fit) = f(:,fit) + df   ! Add correction in fit region
       
          deallocate(df)

       else if (trim(this%method) == 'lotf_adj_pot_sw') then

          call system_abort('lotf_adj_pot_sw no longer supported.')

          ! old style adj pot: SW with variable parameters

!!$          allocate(df(3,this%fitlist%N))
!!$       
!!$          ! old style method: we fit to QM force in embed region and MM force in outer fit region,
!!$          ! not to force difference
!!$          df = f_mm(:,fit)
!!$          df(:,1:this%embedlist%N) = f_qm(:,embed)
!!$
!!$          if (lotf_do_init) &
!!$               call adjustable_potential_sw_init(at, this%fitlist)
!!$
!!$          if (lotf_do_qm .and. lotf_do_fit) &
!!$               call adjustable_potential_sw_optimise(at, df)
!!$
!!$          if (lotf_do_interp) then
!!$             call adjustable_potential_force(at, df, interp=lotf_interp)
!!$          else
!!$             call adjustable_potential_force(at, df)
!!$          end if
!!$       
!!$          f = f_mm           ! start with classical forces
!!$          f(:,fit) = df      ! replace with fitted force
!!$
!!$          deallocate(df)

       end if

    else if (trim(method) == 'conserve_momentum') then
       
       call verbosity_push(PRINT_NORMAL)

       call print('Conserving momentum using fit list with '//this%fitlist%N//' atoms', PRINT_VERBOSE)

       select case(conserve_momentum_weight_method)
       case ('uniform')
          weight_method = UNIFORM_WEIGHT
          call print('conserve_momentum: uniform weighting', PRINT_VERBOSE)
       case ('mass')
          weight_method = MASS_WEIGHT
          call print('conserve_momentum: using mass weighting', PRINT_VERBOSE)
       case ('mass^2')
          weight_method = MASS2_WEIGHT
          call print('conserve_momentum: using mass squared weighting', PRINT_VERBOSE)
       case ('user')
          weight_method = USER_WEIGHT
          call print('conserve_momentum: using user defined weighting', PRINT_VERBOSE)
       case ('weight_region1')
          weight_method = CM_WEIGHT_REGION1
          call print('conserve_momentum: using user defined weighting', PRINT_VERBOSE)
       case default
          call system_abort('Potential_FM_Calc: unknown conserve_momentum_weight method: '//&
               trim(conserve_momentum_weight_method))
       end select

       if (weight_method == USER_WEIGHT) then
          if (.not. assign_pointer(at, 'conserve_momentum_weight', conserve_momentum_weight)) &
               call system_abort('Potential_FM_Calc: missing property conserve_momentum_weight')
       end if

       allocate(df(3,at%N),df_fit(3,this%fitlist%N))

       if (.not. assign_pointer(at, 'weight_region1', weight_region1)) &
            call system_abort('Potential_FM_Calc: missing weight_region1 property - try setting calc_weights=T in args_str')

       ! Straight forward force mixing using weight_region1 created by create_hybrid_weights() 
       do i=1,at%N
          df(:,i) = (weight_region1(i)*f_qm(:,i) + (1.0_dp - weight_region1(i))*f_mm(:,i)) - f_mm(:,i)
       end do

       f_tot = sum(df,dim=2)
       call print('conserve_momentum: norm(sum of target forces) = '//round(norm(f_tot),15), PRINT_VERBOSE)

       w_tot = 0.0_dp
       do i = 1, this%fitlist%N
          select case(weight_method)
          case(UNIFORM_WEIGHT)
             weight = 1.0_dp
          case(MASS_WEIGHT)
             weight = at%mass(fit(i))
          case(MASS2_WEIGHT)
             weight = at%mass(fit(i))*at%mass(fit(i))
          case(USER_WEIGHT)
             weight = conserve_momentum_weight(fit(i))
          case(CM_WEIGHT_REGION1)
             weight = weight_region1(fit(i))
          end select
          df_fit(:,i) = -weight * f_tot
          w_tot = w_tot + weight
       end do
       df_fit = (df_fit / w_tot)

       !NB workaround for pgf90 bug (as of 9.0-1)
       t_norm = norm(sum(df_fit,dim=2));call print('conserve_momentum: norm(sum of    fit forces) = '//round(t_norm, 15), PRINT_VERBOSE)
       !NB end of workaround for pgf90 bug (as of 9.0-1)

       ! Final forces are classical forces plus corrected QM forces
       f = f_mm + df
       f(:,fit) = f(:,fit) + df_fit

       call verbosity_pop()

       deallocate(df, df_fit)
       
    else if (method(1:12) == 'force_mixing') then

       if (.not. assign_pointer(at, 'weight_region1', weight_region1)) &
            call system_abort('Potential_FM_Calc: missing weight_region1 property - try setting calc_weights=T in args_str')

       ! Straight forward force mixing using weight_region1 created by create_hybrid_weights() 
       do i=1,at%N
          f(:,i) = weight_region1(i)*f_qm(:,i) + (1.0_dp - weight_region1(i))*f_mm(:,i)
       end do

    else
       call system_abort('Potential_FM_calc: unknown method '//trim(method))
    end if
       
    ! Save QM and MM forces and total force as properties of Atoms object
    if (save_forces) then
       if (.not. has_property(at, 'qm_force')) &
            call add_property(at, 'qm_force', 0.0_dp, n_cols=3)
       dummy = assign_pointer(at, 'qm_force', force_ptr)
       force_ptr = f_qm

       if (.not. has_property(at, 'mm_force')) &
            call add_property(at, 'mm_force', 0.0_dp, n_cols=3)
       dummy = assign_pointer(at, 'mm_force', force_ptr)
       force_ptr = f_mm

       if (.not. has_property(at, 'force')) &
            call add_property(at, 'force', 0.0_dp, n_cols=3)
       dummy = assign_pointer(at, 'force', force_ptr)
       force_ptr = f
    end if

    deallocate(f_mm,f_qm)

    if (allocated(embed)) deallocate(embed)
    if (allocated(fit))   deallocate(fit)
    
  end subroutine Potential_FM_calc


  function Potential_FM_cutoff(this)
    type(Potential_FM), intent(in) :: this
    real(dp) :: potential_fm_cutoff

    ! Return larger of QM and MM cutoffs
    if(associated(this%mmpot) .and. associated(this%qmpot)) then
       potential_fm_cutoff = max(cutoff(this%mmpot), cutoff(this%qmpot))
    else if(associated(this%qmpot)) then
       potential_fm_cutoff = cutoff(this%qmpot)
    else if(associated(this%mmpot)) then
       potential_fm_cutoff = cutoff(this%mmpot)
    else
       potential_fm_cutoff = 0.0_dp
    endif

  end function Potential_FM_cutoff

