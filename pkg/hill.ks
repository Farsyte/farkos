@LAZYGLOBAL off.
{   parameter hill is lex(). // Hillclimb Algorithm Library

    // Hillclimb Algorithm Library
    // Kevin Gisi
    // http://youtube.com/gisikw
    //
    // His version 0.1.0 of the hillclimb.ks package
    // is seen in Episode 039 and recorded in Github
    // at https://github.com/gisikw/ksprogramming.git
    // in episodes/e039/hillclimb.v0.1.0.ks
    //
    // Changes:
    // - added attribution comment above
    // - added limited documentation of the API
    // - added support for ABORT
    // - refactoring to fit my package system
    // - mangled the formatting to pander to VS Code "block hide"
    //
    // Parameters passed here:
    //   data                   // current state vector
    //   fitness_fn             // delegate to evaluation function
    //   step_sizes             // list of step sizes to use
    //   step_size              // amount to change each element

    hill:add("seeks", {         // Run a hill:SEEK for each given step size.
        parameter data, fitness_fn, step_sizes.
        for step_size in step_sizes
            set data to hill:seek(data, fitness_fn, step_size).
        return data. }).

    hill:add("seek", {          // step to BEST neighbor until done
        parameter data, fitness_fn, step_size.
        until abort {
            local next_data is hill:best(data, fitness_fn, step_size).
            if fitness_fn(next_data) <= fitness_fn(data) return data.
            set data to next_data. } }).

    hill:add("best", {          // pick BEST of the NEAR candidates
        parameter data, fitness_fn, step_size.
        local best is data.
        local best_fitness is fitness_fn(best).
        for neighbor in hill:near(data, step_size) {
            local fitness is fitness_fn(neighbor).
            if fitness > best_fitness {
                set best to neighbor.
                set best_fitness to fitness. } }
        return best. }).

    hill:add("near", {          // construct neighbors of data
        parameter data, step_size.
        local results is list().
        for i in range(0, data:length) {
            if data[i]:istype("Scalar") {

                local increment is data:copy.
                set increment[i] to increment[i] + step_size.
                results:add(increment).

                local decrement is data:copy.
                set decrement[i] to decrement[i] - step_size.
                results:add(decrement). } }
        return results.}). }
