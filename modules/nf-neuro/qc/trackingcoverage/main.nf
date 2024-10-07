process QC_TRACKINGCOVERAGE {
    tag "$meta.id"
    label 'process_single'

    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://scil.usherbrooke.ca/containers/scilus_2.0.2.sif':
        'scilus/scilus:latest' }"

    input:
        tuple val(meta), path(tractogram), path(mask)

    output:
        tuple val(meta), path("${prefix}_tractogram_mask.nii.gz")   , emit: tractogram_mask
        tuple val(meta), path("${prefix}_TDI.nii.gz")               , emit: TDI
        tuple val(meta), path("${prefix}_stats.json")               , emit: stats
        tuple val(meta), path("${prefix}_sc.txt")                   , emit: sc
        tuple val(meta), path("${prefix}_coverage_overlay.png")     , emit: png
        path "versions.yml"                                         , emit: versions

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
    scil_tractogram_count_streamlines.py $tractogram --print_count_alone > ${prefix}_sc.txt

    # Computing TODI.
    scil_tractogram_compute_TODI.py $tractogram \
        --out_mask ${prefix}_tractogram_mask.nii.gz \
        --out_tdi ${prefix}_TDI.nii.gz \
        $sh_basis $sphere $sh_order $normalize_per_voxel \
        $smooth_todi $asymmetric $n_steps

    # Computing DICE score.
    scil_volume_pairwise_comparison.py $mask ${prefix}_tractogram_mask.nii.gz \
        ${prefix}_stats.json

    # Visual QC file.
    scil_viz_volume_screenshot.py ${prefix}_TDI.nii.gz ${prefix}_coverage_overlay.png \
        --volume_cmap pink \
        --overlays $mask \
        --overlays_opacity 0 \
        --overlays_as_contours \
        --display_slice_number \
        --display_lr \
        --overlays_colors 0 255 0 \
        --slices 75 \
        --axis axial

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        scilpy: \$(pip list | grep scilpy | tr -s ' ' | cut -d' ' -f2)
    END_VERSIONS
    """

    stub:
    def prefix = task.ext.prefix ?: "${meta.id}"

    """
    touch ${prefix}_tractogram_mask.nii.gz
    touch ${prefix}_TDI.nii.gz
    touch ${prefix}_stats.json
    touch ${prefix}_sc.txt
    touch ${prefix}_coverage_overlay.png

    scil_tractogram_count_streamlines.py -h
    scil_tractogram_compute_TODI.py -h
    scil_volume_pairwise_comparison.py -h
    scil_viz_volume_screenshot.py -h

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        scilpy: \$(pip list | grep scilpy | tr -s ' ' | cut -d' ' -f2)
    END_VERSIONS
    """
}
