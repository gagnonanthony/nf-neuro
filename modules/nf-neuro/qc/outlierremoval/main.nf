process QC_OUTLIERREMOVAL {
    tag "$meta.id"
    label 'process_single'

    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://scil.usherbrooke.ca/containers/scilus_2.0.2.sif':
        'scilus/scilus:latest' }"

    input:
        path(sc), path(dice)

    output:
        path "outliers.txt"                     , emit: outliers
        path "distributions.png"                , emit: png
        path "versions.yml"                     , emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    """
    #!/usr/bin/env python

    # Install ajustText for pretty labelling of points.
    subprocess.call(['pip', 'install', 'adjustText'])

    import json
    import os
    import random
    import subprocess

    from adjustText import adjust_text
    import pandas as pd
    import matplotlib.pyplot as plt
    import numpy as np

    # Some functions for boxplots, scatterplots, and aesthetics.
    def husl_palette(n_colors):
        return plt.cm.hsv(np.linspace(0, 1, n_colors))

    def plot_box_strip(ax, data, labels, title, y_label, colors):
        # Boxplot
        box = ax.boxplot(data, whis=3, patch_artist=True, 
                        boxprops=dict(facecolor='lightblue', color='black'), 
                        capprops=dict(color='black'),
                        whiskerprops=dict(color='black'),
                        flierprops=dict(marker='o', color='black', markersize=5),
                        medianprops=dict(color='red'))

        # Set colors for each box and matching points
        for patch, color in zip(box['boxes'], colors):
            patch.set_facecolor(color)

        # Strip plot equivalent: jitter points for visibility, colored to match boxes
        for i in range(len(data)):
            x_vals = np.random.normal(i + 1, 0.04, size=len(data[i]))  # jitter points
            ax.scatter(x_vals, data[i], alpha=0.5, color=colors[i], s=15)  # points

        ax.set_title(title, fontsize=12, fontweight='bold')
        ax.set_ylabel(y_label, fontsize=10, fontweight='bold')
        ax.set_xticks(range(1, len(labels) + 1))
        ax.set_xticklabels(labels, rotation=45, ha='right', fontsize=10)

    # Iteratively load the streamline counts and DICE scores and append them into a df.
    df = pd.DataFrame()
    for sc, dice in zip($sc, $dice):
        subid = os.path.basename(sc).split("__")[0]
        scount = open(sc).read()
        with open(dice, "r") as f:
            dice_score = json.load(f)
            dice_score = dice_score["dice_voxels"]["1"][0]
        df = pd.concat(
            [
                df,
                pd.DataFrame(
                    {
                        "subjectkey": subids,
                        "SC": scount,
                        "DICE": dice_score,
                    },
                    index=[0],
                ),
            ],
            axis=0
        )
    
    # Fetch inter-quartile range (IQR) for both metrics.
    iqr = []
    for var in df.columns[1:]:
        q75, q25 = np.percentile(df[var], [75, 25])
        iqr.append([q25, q75])

    # Create figure object. 
    fig, ax = plt.subplots(1, 2, figsize=(16, 12))

    plot_box_strip(ax[0], df, "SC", "Streamline Counts", "Streamline Counts",
                   husl_palette(10)[4])
    plot_box_strip(ax[1], df, "DICE", "DICE Scores", "Dice Scores",
                   husl_palette(10)[7])
    
    # Add label to ouliers.
    subids = []
    text = []
    for i, val in enumerate(df["SC"]):
        if val < (iqr[0][0] - (3 * (iqr[0][1] - iqr[0][0]))) or val > (iqr[0][1] + (3 * (iqr[0][1] - iqr[0][0]))):
            subids.append(df["subjectkey"][i])
            text.append(ax[0].text(1, val, df["subjectkey"][i], ha='center', va='center', fontsize=10, color='black'))
    
    # Randomly select maximum 15 outliers to annotate on the graph.
    if len(text) > 15:
        text = random.sample(text, 15)
        adjust_text(text, ax=ax[0], iter_lim=1000, arrowprops=dict(arrowstyle="->", color="black"))
    else:
        adjust_text(text, ax=ax[0], iter_lim=1000, arrowprops=dict(arrowstyle="->", color="black"))

    text = []
    for i, val in enumerate(df["DICE"]):
        if val < (iqr[1][0] - (3 * (iqr[1][1] - iqr[1][0]))) or val > (iqr[1][1] + (3 * (iqr[1][1] - iqr[1][0]))):
            subids.append(df["subjectkey"][i])
            text.append(ax[1].text(1, val, df["subjectkey"][i], ha='center', va='center', fontsize=10, color='black'))
    
    if len(text) > 15:
        text = random.sample(text, 15)
        adjust_text(text, ax=ax[1], iter_lim=1000, arrowprops=dict(arrowstyle="->", color="black"))
    else:
        adjust_text(text, ax=ax[1], iter_lim=1000, arrowprops=dict(arrowstyle="->", color="black"))

    # Add labels for upper and lower rows.
    plt.gcf().text(0, 0.96, "A", fontsize=20, fontweight='bold')
    plt.gcf().text(0.51, 0.96, "B", fontsize=20, fontweight='bold')

    txt = r"$\bf{"+str("Figure.")+"}$" + "Distribution of total streamline count and DICE scores across the processed subjects. " + \
            "For visualization purposes, maximum 15 outliers are labelled (defined as over or under 3 * IQR). " + \
            r"$\bf{"+"A."+"}$" + "Streamline Counts. " + r"$\bf{"+"B."+"}$" + "DICE Scores."

    plt.figtext(0.5, -0.06, txt, wrap=True, horizontalalignment='center', fontsize=12)

    plt.tight_layout()
    plt.savefig("distributions.png", dpi=900, bbox_inches="tight")
    """
    """
    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        qc: 1.0.0
    END_VERSIONS
    """

    stub:
    """
    touch outliers.txt
    touch distributions.png

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        qc: 1.0.0
    END_VERSIONS
    """
}
