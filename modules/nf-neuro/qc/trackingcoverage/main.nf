process QC_TRACKINGCOVERAGE {
    tag "$meta.id"
    label 'process_single'

    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://scil.usherbrooke.ca/containers/scilus_2.0.2.sif':
        'scilus/scilus:latest' }"

    input:
        tuple val(meta), path(tractogram), path(mask)

    output:
        tuple val(meta), path("*__tractogram_mask.nii.gz")   , emit: tractogram_mask
        tuple val(meta), path("*__TDI.nii.gz")               , emit: TDI
        tuple val(meta), path("*__stats.json")               , emit: stats
        tuple val(meta), path("*__sc.txt")                   , emit: sc
        path "*.png"                                         , emit: png
        path "versions.yml"                                  , emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def prefix = task.ext.prefix ?: "${meta.id}"

    def sh_basis = task.ext.sh_basis ? "--sh_basis ${task.ext.sh_basis}" : ''
    def sphere = task.ext.sphere ? "--sphere ${task.ext.sphere}" : ''
    def sh_order = task.ext.sh_order ? "--sh_order ${task.ext.sh_order}" : ''
    def normalize_per_voxel = task.ext.normalize_per_voxel ? "--normalize_per_voxel" : ''
    def smooth_todi = task.ext.smooth_todi ? "--smooth_todi" : ''
    def asymmetric = task.ext.asymmetric ? "--asymmetric" : ''
    def n_steps = task.ext.n_steps ? "--n_steps ${task.ext.n_steps}" : ''

    """
    scil_tractogram_count_streamlines.py $tractogram --print_count_alone > ${prefix}__sc.txt

    # Computing TODI.
    scil_tractogram_compute_TODI.py $tractogram \
        --out_mask ${prefix}__tractogram_mask.nii.gz \
        --out_tdi ${prefix}__TDI.nii.gz \
        $sh_basis $sphere $sh_order $normalize_per_voxel \
        $smooth_todi $asymmetric $n_steps

    # Computing DICE score.
    scil_volume_pairwise_comparison.py $mask ${prefix}__tractogram_mask.nii.gz \
        ${prefix}__stats.json

    # Fetch middle axial slice.
    size=\$(mrinfo ${prefix}__TDI.nii.gz -size)
    mid_slice=\$(echo \$size | awk '{print int((\$2 + 1) / 2)}')

    # Visual QC file.
    scil_viz_volume_screenshot.py ${prefix}__TDI.nii.gz ${prefix}__coverage_overlay.png \
        --volume_cmap pink \
        --overlays $mask \
        --overlays_opacity 0 \
        --overlays_as_contours \
        --display_slice_number \
        --display_lr \
        --overlays_colors 0 255 0 \
        --slices \$mid_slice \
        --axis axial

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        scilpy: \$(pip list --disable-pip-version-check --no-python-version-warning | grep scilpy | tr -s ' ' | cut -d ' ' -f2)
    END_VERSIONS
    """

    stub:
    def prefix = task.ext.prefix ?: "${meta.id}"

    """
    touch ${prefix}__tractogram_mask.nii.gz
    touch ${prefix}__TDI.nii.gz
    touch ${prefix}__stats.json
    touch ${prefix}__sc.txt
    touch ${prefix}__coverage_overlay.png

    scil_tractogram_count_streamlines.py -h
    scil_tractogram_compute_TODI.py -h
    scil_volume_pairwise_comparison.py -h
    scil_viz_volume_screenshot.py -h

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        scilpy: \$(pip list --disable-pip-version-check --no-python-version-warning | grep scilpy | tr -s ' ' | cut -d ' ' -f2)
    END_VERSIONS
    """
}
