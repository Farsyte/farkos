// Hillclimb Algorithm Library
// Kevin Gisi
// http://youtube.com/gisikw
//
// hillclimb.ks is his version 0.1.0 of that package,
// as seen in Episode 039 and recorded in Github
// at https://github.com/gisikw/ksprogramming.git
// in episodes/e039/hillclimb.v0.1.0.ks
//
// Changes:
// - added attribution comment above
// - added limited documentation of the API

{
    local INFINITY is 2^64.
    local DEFAULT_STEP_SIZE is 1.

    global hillclimb is lex(
        "version", "0.1.0",
        "seek", seek@ ).

    // HILLCLIMB:SEEK(data, fitness_fn, step_size)
    //   data             current state vector
    //   fitness_fn       delegate to evaluation function
    //   step_size        element step size for BEST_NEIGHBOR
    //
    // The SEEK method uses BEST_NEIGHBOR to select the highest
    // scoring neighboring state. This process is repeated until
    // the best neighbor is not better than the current state.
    //
    function seek {
        parameter data, fitness_fn, step_size is DEFAULT_STEP_SIZE.
        until abort {
            local next_data is best_neighbor(data, fitness_fn, step_size).
            if fitness_fn(next_data) <= fitness_fn(data) break.
            set data to next_data.  }
        return data. }

    // HILLCLIMB:BEST_NEIGHBOR(data, fitness_fn, step_size)
    //   data             current state vector
    //   fitness_fn       delegate to evaluation function
    //   step_size        element step size for NEIGHBORS
    //
    // The BEST_NEIGHBOR method uses NEIGHBORS to construct the state
    // vectors that neighbor the given data vector, evaluates each one
    // for fitness, and returns the one whose fitness is best.
    //
    // Returns original data if it has no neighbors.
    //
    function best_neighbor {
        parameter data, fitness_fn, step_size.
        local best_fitness is -INFINITY.
        local best is data.
        for neighbor in neighbors(data, step_size) {
            local fitness is fitness_fn(neighbor).
            if fitness > best_fitness {
                set best to neighbor.
                set best_fitness to fitness. } }
        return best. }

    // HILLCLIMB:NEIGHBORS
    //   data             current state vector
    //   step_size        element step size for NEIGHBORS
    //   results          output list
    //
    // The NEIGHBORS method iterates through the elements
    // of the data vector input; for each, it creates new
    // member state vectors that differ from data in that
    // element by plus or minus the step size.
    //
    // The neighbors are appended to the result list, which
    // is returned.
    //
    function neighbors {
        parameter data, step_size, results is list().
        for i in range(0, data:length) {
            if data[i]:istype("Scalar") {

                local increment is data:copy.
                set increment[i] to increment[i] + step_size.
                results:add(increment).

                local decrement is data:copy.
                set decrement[i] to decrement[i] - step_size.
                results:add(decrement). } }
        return results. } }
