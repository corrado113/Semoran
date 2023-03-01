# SEM-O-RAN
Code repository to reproduce the results of our paper "SEM-O-RAN: Semantic and Flexible O-RAN Slicing for NextG Edge-Assisted Mobile Systems", accepted for publication at IEEE INFOCOM 2023


## Content
This repository contains the following files:
*   LICENSE
    
    This file contains the license covering the software and associated documentation files provided in this repository.

*   README.md
    
    This is the file that contains the instructions to use the provided software and that you are currently reading.

*   example.m

    This MATLAB script is an example of how to use the SF-ESP solver.


*   example_live.mlx

    The same as above, but as a MATLAB Live Script for easier interaction.

*   greedy_knapsack.m

    A MATLAB function that implements a knapack problem solver, which is used as a baseline competitor of SEM-O-RAN in the provided example.

*   semoran.m

    The MATLAB function that implements the solver of the Semantic Flexible Edge Slicing Problem (SF-ESP).

## Instructions
To test our code, clone this repository using the following command:
```
git clone https://github.com/corrado113/Semoran.git
```
Then, run with MATLAB example_live.mlx or example.m.

## Cite us
If you have used our work in your research, please consider citing our paper:

```
@article{puligheddu2022sem,
  title={SEM-O-RAN: Semantic and Flexible O-RAN Slicing for NextG Edge-Assisted Mobile Systems},
  author={Puligheddu, Corrado and Ashdown, Jonathan and Chiasserini, Carla Fabiana and Restuccia, Francesco},
  journal={arXiv preprint arXiv:2212.11853},
  year={2022},
  doi={10.48550/arXiv.2212.11853}
}
```

## Changelog
*   01/03/2023 
    *   Upload of new files in the repository:
        *   the SEM-O-RAN solver matlab function
        *   a baseline knapsack problem solver
        *   two example files to test SEM-O-RAN and compare it with a baseline competitor
    *   Extension of the README.md file, which now contains:
        *   the content list of the repository
        *   instructions on how to use the provided code
        *   the reference to the SEM-O-RAN paper preprint