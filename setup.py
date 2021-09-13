import setuptools

setuptools.setup(
    name='opn_tools',
    version='0.0.1',
    packages=[
        'mkopn',
    ],
    entry_points={
        'console_scripts': [
            'mkopn = mkopn:main',
        ],
    },
)
