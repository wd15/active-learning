---
jupyter:
  jupytext:
    formats: ipynb,md
    text_representation:
      extension: .md
      format_name: markdown
      format_version: '1.3'
      jupytext_version: 1.14.5
  kernelspec:
    display_name: Python 3 (ipykernel)
    language: python
    name: python3
---

```python tags=["parameters"]
iterations = 400
input_file = 'data_pca_test.npz'
output_file = 'active_data.h5'
```

```python
from tqdm.notebook import trange, tqdm
import numpy as np
from active import split_on_ids, next_sample_gsx, next_sample_igs
from sklearn.gaussian_process.kernels import Matern
from sklearn.gaussian_process import GaussianProcessRegressor
import h5py
import hdfdict
```

```python
def train_test_split_(x_data, y_data, prop, random_state=None):
    ids = np.random.choice(len(x_data), int(prop * len(x_data)), replace=False)
    x_0, x_1 = split_on_ids(x_data, ids)
    y_0, y_1 = split_on_ids(y_data, ids)
    return x_0, x_1, y_0, y_1
```

```python
def split(x_data, y_data, train_sizes=(0.9, 0.09), random_state=None):
    x_pool, x_, y_pool, y_ = train_test_split_(
        x_data,
        y_data,
        train_sizes[0],
        random_state=random_state
    )
    x_test, x_calibrate, y_test, y_calibrate = train_test_split_(
        x_,
        y_,
        train_sizes[1] / (1 - train_sizes[0]),
        random_state=random_state
    ) 
    return x_pool, x_test, x_calibrate, y_pool, y_test, y_calibrate
```

```python
def make_gp_model_matern():
    kernel = Matern(length_scale=1.0)
    regressor = GaussianProcessRegressor(kernel=kernel)
    return regressor
```

```python
def run_all(x_data_pca, y_data, train_sizes, learners, n_query):
    data = split(x_data_pca, y_data, train_sizes)
    test_scores = dict()
    for k in tqdm(learners, position=1, desc="learner loop"):
        test_scores[k] = run(data, learners[k][0], learners[k][1], n_query)[1]
    return test_scores
```

```python
def query_helper(model, x_pool, y_pool, init_scores, update_scores, next_func):
    if not hasattr(model, 'query_data'):
        model.query_data = [], init_scores()
    labeled_samples, scores = model.query_data
    scores = update_scores(model, scores)
    next_id = next_func(labeled_samples, scores)
    model.query_data = (labeled_samples + [next_id], scores)
    x_, _, y_, _ = rework_pool(x_pool, y_pool, [next_id])
    return x_, x_pool, y_, y_pool


def gsx_query(model, x_pool, y_pool):
    return query_helper(
        model,
        x_pool,
        y_pool,
        lambda: x_pool,
        lambda m, s: s,
        next_sample_gsx
    )

def gsy_query(model, x_pool, y_pool):
    return query_helper(
        model,
        x_pool,
        y_pool,
        lambda: None,
        lambda m, s: m.predict(x_pool).reshape(-1, 1),
        next_sample_gsx
    )


def igs_query(model, x_pool, y_pool):
    return query_helper(
        model,
        x_pool,
        y_pool,
        lambda: (x_pool, None),
        lambda m, s: (s[0], m.predict(x_pool).reshape(-1, 1)),
        next_sample_igs
    )


def query_uncertainty(model, x_pool, y_pool):
    stds = model.predict(x_pool, return_std=True)[1]
    ids = np.argsort(stds)[::-1][:1]
    return rework_pool(x_pool, y_pool, ids)

def query_random(model, x_pool, y_pool):
    ids = np.random.choice(len(x_pool), 1, replace=False)
    return rework_pool(x_pool, y_pool, ids)


def run(data, query_func, model_func, n_iter, train_sizes=(0.87, 0.004)):
    x_pool, x_test, x_train, y_pool, y_test, y_train = data
    
    model = model_func()
    train_scores = []
    test_scores = []
    
    for _ in trange(n_iter, position=2, desc='iter loop'):
        model, x_pool, x_train, y_pool, y_train, test_score, train_score  = evaluate_model(
            x_pool, x_test, x_train, y_pool, y_test, y_train,
            model, 
            query_func
        )
        
        train_scores += [train_score]
        test_scores += [test_score]
       
    return train_scores, test_scores

def evaluate_model(x_pool, x_test, x_train, y_pool, y_test, y_train, model, query_func):
    model.fit(x_train, y_train)
    train_score = model.score(x_train, y_train)
    test_score = model.score(x_test, y_test)
    x_, x_pool, y_, y_pool = query_func(model, x_pool, y_pool)
    x_train = np.vstack([x_train, x_])
    y_train = np.append(y_train, y_)
    return model, x_pool, x_train, y_pool, y_train, test_score, train_score

def rework_pool(x_pool, y_pool, ids):
    x_, x_pool = split_on_ids(x_pool, ids)
    y_, y_pool = split_on_ids(y_pool, ids)
    return x_, x_pool, y_, y_pool
```

```python
learners_gp = dict(
    uncertainty=(query_uncertainty, make_gp_model_matern),
    random=(query_random, make_gp_model_matern),
    gsx=(gsx_query, make_gp_model_matern),
    gsy=(gsy_query, make_gp_model_matern),
    igs=(igs_query, make_gp_model_matern)
)
```

```python
data = np.load(input_file)
x_data_pca = data['x_data_pca']
y_data = data['y_data']
```

```python
data = run_all(x_data_pca, y_data, (0.795, 0.2), learners_gp, iterations)
```

```python
# from https://github.com/SiggiGue/hdfdict/issues/6

f = h5py.File(output_file, 'w')
hdfdict.dump(data, output_file)
f.close()

```

```python

```